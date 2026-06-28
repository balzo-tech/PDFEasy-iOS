//
//  OcrUtility.swift
//  PdfExpert
//
//  OCR + searchable PDF generation.
//
//  Runs Apple's on-device Vision text recognition over the image-only pages of a
//  PDF and rebuilds each of them as the original bitmap plus an *invisible* text
//  layer positioned on Vision's bounding boxes. The result is a PDF whose scanned
//  pages become selectable and searchable, while pages that already carry vector
//  text are left untouched (re-rendering them would only throw away quality).
//

import Foundation
import SwiftUI
import PDFKit
import Vision
import CoreText

class OcrUtility {

    /// Recognition languages, BCP-47. The app ships EN/IT, so OCR targets both.
    static let defaultLanguages = ["it-IT", "en-US"]

    /// Render multiplier applied to a page's point size before OCR. PDF user space
    /// is 72 dpi; ~2x lands the bitmap around 144 dpi, enough for accurate OCR
    /// without ballooning memory. Clamped by `maxRenderDimension`.
    static let defaultRenderScale: CGFloat = 2.0

    /// Upper bound on the long edge of the rasterized page (px), to cap memory on
    /// very large pages.
    static let maxRenderDimension: CGFloat = 4000

    /// JPEG quality used to re-encode the rasterized page before embedding it.
    /// OCR'd pages are inherently images (a scan), so JPEG shrinks them a lot with
    /// negligible quality loss for scanned text. `1.0` disables compression.
    static let defaultJpegQuality: CGFloat = 0.7

    // MARK: - Async entry point

    /// Asynchronous, progress-reporting entry point mirroring
    /// `PdfScanUtility.convertScan`: drives an `AsyncOperation` binding so the
    /// editor can show a per-page progress bar and pick up the resulting `Pdf`.
    static func makeSearchable(pdf: Pdf,
                               languages: [String] = defaultLanguages,
                               jpegQuality: CGFloat = defaultJpegQuality,
                               asyncOperation: Binding<AsyncOperation<Pdf, PdfError>>) {

        let document = pdf.pdfDocument
        let progress = Progress(totalUnitCount: Int64(max(document.pageCount, 1)))
        asyncOperation.wrappedValue = AsyncOperation(status: .loading(progress))

        DispatchQueue.global(qos: .userInitiated).async {
            let searchableDocument = Self.makeSearchableDocument(from: document,
                                                                 languages: languages,
                                                                 jpegQuality: jpegQuality) { completed, _ in
                DispatchQueue.main.async {
                    progress.completedUnitCount = Int64(completed)
                    asyncOperation.wrappedValue = AsyncOperation(status: .loading(progress))
                }
            }

            DispatchQueue.main.async {
                if let searchableDocument {
                    var newPdf = pdf
                    newPdf.updateDocument(searchableDocument)
                    asyncOperation.wrappedValue = AsyncOperation(status: .data(newPdf))
                } else {
                    asyncOperation.wrappedValue = AsyncOperation(status: .error(.unknownError))
                }
            }
        }
    }

    // MARK: - Synchronous core (unit-testable)

    /// Returns a new document where every image-only page carries an invisible OCR
    /// text layer. Pages that already have extractable text are kept verbatim.
    /// Returns `nil` only if the source document can't be copied.
    /// - Parameter progress: called as `(completedPages, totalPages)` after each page.
    static func makeSearchableDocument(from document: PDFDocument,
                                       languages: [String] = defaultLanguages,
                                       renderScale: CGFloat = defaultRenderScale,
                                       jpegQuality: CGFloat = defaultJpegQuality,
                                       progress: ((Int, Int) -> Void)? = nil) -> PDFDocument? {

        let pageCount = document.pageCount
        guard pageCount > 0 else { return document }

        // Work on a copy so the caller's document is never mutated.
        guard let copy = document.dataRepresentation().flatMap({ PDFDocument(data: $0) }) else {
            return nil
        }

        for index in 0..<pageCount {
            defer { progress?(index + 1, pageCount) }

            guard let page = copy.page(at: index) else { continue }

            // Pages that already carry selectable text are kept as-is: they're
            // already searchable and rasterizing them would discard vector quality.
            let hasText = !(page.string ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            if hasText { continue }

            // OCR + rebuild. If nothing is recognized (or rendering fails) the
            // original page is left in place.
            guard let searchablePage = Self.makeSearchablePage(from: page,
                                                               languages: languages,
                                                               renderScale: renderScale,
                                                               jpegQuality: jpegQuality) else {
                continue
            }

            copy.removePage(at: index)
            copy.insert(searchablePage, at: index)
        }

        return copy
    }

    /// OCRs a single page and rebuilds it as `image + invisible text layer`.
    /// Returns `nil` when no text is recognized or the page can't be rendered, so
    /// the caller keeps the original page.
    static func makeSearchablePage(from page: PDFPage,
                                   languages: [String] = defaultLanguages,
                                   renderScale: CGFloat = defaultRenderScale,
                                   jpegQuality: CGFloat = defaultJpegQuality) -> PDFPage? {

        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }

        // 1. Rasterize the page: serves both as OCR input and as the visible layer.
        guard let pageImage = Self.renderPageImage(page: page, scale: renderScale),
              let cgImage = pageImage.cgImage else {
            return nil
        }

        // 2. Recognize text.
        let observations = Self.recognizeText(in: cgImage, languages: languages)
        guard !observations.isEmpty else { return nil }

        // 3. Rebuild the page at its original size: draw the (JPEG-compressed)
        // bitmap, then overlay the recognized text invisibly so it becomes
        // selectable/searchable.
        let imageToDraw = Self.compressedImage(pageImage, quality: jpegQuality)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageRect.size))
        let data = renderer.pdfData { context in
            context.beginPage()
            imageToDraw.draw(in: CGRect(origin: .zero, size: pageRect.size))
            Self.drawInvisibleText(observations: observations,
                                   in: context.cgContext,
                                   pageSize: pageRect.size)
        }

        return PDFDocument(data: data)?.page(at: 0)
    }

    /// Runs Vision text recognition over a bitmap and returns the line-level
    /// observations. Never throws: on failure it returns an empty array so the
    /// caller can fall back to the original page.
    static func recognizeText(in cgImage: CGImage,
                              languages: [String] = defaultLanguages) -> [VNRecognizedTextObservation] {

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results as? [VNRecognizedTextObservation]) ?? []
    }

    // MARK: - Private helpers

    /// Renders a page to a bitmap, scaled by `scale` but capped so the long edge
    /// never exceeds `maxRenderDimension`.
    private static func renderPageImage(page: PDFPage, scale: CGFloat) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let longEdge = max(pageRect.width, pageRect.height)
        let clampedScale = longEdge > 0 ? min(scale, Self.maxRenderDimension / longEdge) : scale
        let targetSize = CGSize(width: pageRect.width * clampedScale,
                                height: pageRect.height * clampedScale)
        return page.thumbnail(of: targetSize, for: .mediaBox)
    }

    /// Re-encodes the image as JPEG at `quality` so it embeds compactly. Returns
    /// the original image when compression is disabled (`quality >= 1`) or fails.
    private static func compressedImage(_ image: UIImage, quality: CGFloat) -> UIImage {
        guard quality < 1.0,
              let jpegData = image.jpegData(compressionQuality: quality),
              let compressed = UIImage(data: jpegData) else {
            return image
        }
        return compressed
    }

    /// Draws the recognized text as an invisible, *word-level* layer: each word is
    /// placed on its own Vision bounding box so text selection maps tightly to the
    /// underlying glyphs (falling back to the whole line if per-word boxes are
    /// unavailable). The context is flipped to a y-up space that matches Vision's
    /// normalized, bottom-left-origin coordinates; `setTextDrawingMode(.invisible)`
    /// emits the glyphs into the content stream (so PDFKit can extract them)
    /// without painting anything.
    private static func drawInvisibleText(observations: [VNRecognizedTextObservation],
                                          in cg: CGContext,
                                          pageSize: CGSize) {
        cg.saveGState()
        // UIGraphicsPDFRenderer hands us a UIKit (top-left, y-down) context; flip
        // to y-up so denormalized Vision boxes map directly.
        cg.translateBy(x: 0, y: pageSize.height)
        cg.scaleBy(x: 1, y: -1)
        cg.setTextDrawingMode(.invisible)

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            guard !text.isEmpty else { continue }

            var drewAnyWord = false
            let fullRange = text.startIndex..<text.endIndex
            text.enumerateSubstrings(in: fullRange, options: .byWords) { substring, range, _, _ in
                guard let word = substring, !word.isEmpty,
                      let wordBox = try? candidate.boundingBox(for: range) else { return }
                let rect = Self.denormalize(wordBox.boundingBox, pageSize: pageSize)
                if Self.drawText(word, in: rect, context: cg) { drewAnyWord = true }
            }

            // Fallback: no per-word boxes were drawable, place the whole line.
            if !drewAnyWord {
                let rect = Self.denormalize(observation.boundingBox, pageSize: pageSize)
                _ = Self.drawText(text, in: rect, context: cg)
            }
        }

        cg.restoreGState()
    }

    /// Maps a Vision-normalized (y-up) box to page-point coordinates.
    private static func denormalize(_ box: CGRect, pageSize: CGSize) -> CGRect {
        CGRect(x: box.minX * pageSize.width,
               y: box.minY * pageSize.height,
               width: box.width * pageSize.width,
               height: box.height * pageSize.height)
    }

    /// Draws `text` invisibly so it fills `rect` (in the current y-up space).
    /// Returns false when the box is too small or the text has no width.
    @discardableResult
    private static func drawText(_ text: String, in rect: CGRect, context cg: CGContext) -> Bool {
        guard rect.width > 1, rect.height > 1 else { return false }

        let font = CTFontCreateWithName("Helvetica" as CFString, rect.height, nil)
        let attributed = NSAttributedString(
            string: text,
            attributes: [kCTFontAttributeName as NSAttributedString.Key: font]
        )
        let line = CTLineCreateWithAttributedString(attributed)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let naturalWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        guard naturalWidth > 0 else { return false }

        // Horizontally stretch the glyphs to span the box so selection maps closely.
        cg.textMatrix = CGAffineTransform(scaleX: rect.width / naturalWidth, y: 1)
        cg.textPosition = CGPoint(x: rect.minX, y: rect.minY + descent)
        CTLineDraw(line, cg)
        return true
    }
}
