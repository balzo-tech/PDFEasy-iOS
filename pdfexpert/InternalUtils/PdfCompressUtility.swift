//
//  PdfCompressUtility.swift
//  PdfExpert
//
//  "Compress PDF": shrink a document by re-encoding the pages that are actually
//  made of pixels, and leaving the rest alone.
//
//  What makes a PDF heavy is almost always a scan or an embedded photo stored at
//  camera resolution. Those pages are re-rendered at a bounded resolution and
//  re-embedded as JPEG. A page whose content is text and vectors is copied
//  **untouched**: rasterizing it would cost its selectable text and its crispness
//  while saving next to nothing — the exact trade the old share-time compression
//  made on the whole document.
//
//  Apple's APIs cannot recompress a single embedded image while keeping the rest
//  of the page vector, so a page that mixes a large photo with a caption is
//  flattened whole. That is a known trade-off of the Apple APIs, not a choice.
//

import Foundation
import UIKit
import PDFKit

/// How hard to squeeze. Each preset is a bound on resolution plus a JPEG quality:
/// resolution is what actually shrinks a scan, quality is what preserves it.
enum CompressionPreset: Int32, CaseIterable, Identifiable {

    case light, balanced, maximum

    var id: Int32 { self.rawValue }

    /// Longest side, in pixels, a rasterized page may keep. 1600 px still reads
    /// well on screen and prints acceptably at A4; below ~1000 px text in a scan
    /// starts to break up.
    var maxPixelSize: CGFloat {
        switch self {
        case .light: return 2400
        case .balanced: return 1600
        case .maximum: return 1100
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .light: return 0.8
        case .balanced: return 0.6
        case .maximum: return 0.4
        }
    }

    var title: String {
        switch self {
        case .light: return String(localized: "Light")
        case .balanced: return String(localized: "Balanced")
        case .maximum: return String(localized: "Maximum")
        }
    }

    var subtitle: String {
        switch self {
        case .light: return String(localized: "Barely visible quality loss")
        case .balanced: return String(localized: "Good quality, much smaller")
        case .maximum: return String(localized: "Smallest file, visible loss")
        }
    }

    var trackingParameterValue: String {
        switch self {
        case .light: return "light"
        case .balanced: return "balanced"
        case .maximum: return "maximum"
        }
    }
}

struct CompressionResult {

    let document: PDFDocument
    let originalByteCount: Int
    let compressedByteCount: Int
    /// How many pages were re-encoded; the rest were carried over as they were.
    let recompressedPageCount: Int

    /// 0…1. Zero when the result is not smaller — which happens, and the UI has to
    /// be able to say so instead of showing a negative saving.
    var savedFraction: Double {
        guard self.originalByteCount > 0, self.compressedByteCount < self.originalByteCount else { return 0 }
        return 1 - Double(self.compressedByteCount) / Double(self.originalByteCount)
    }

    var isSmaller: Bool { self.compressedByteCount < self.originalByteCount }
}

class PdfCompressUtility {

    /// Compresses `document`, reporting progress in 0…1 on an arbitrary queue.
    ///
    /// Returns nil only when the document cannot be read at all; a document that
    /// simply cannot be shrunk comes back with `isSmaller == false`, so the caller
    /// can tell the user rather than silently saving a bigger file.
    static func compress(document: PDFDocument,
                         preset: CompressionPreset,
                         progress: ((Double) -> Void)? = nil) -> CompressionResult? {

        guard let originalData = document.dataRepresentation() else { return nil }
        // Work on a copy of the original and swap out only the pages that are worth
        // re-encoding, rather than assembling a fresh document: rebuilding from
        // scratch re-emits shared resources (fonts above all) once per page, and a
        // text-only document comes back *heavier* than it went in.
        guard document.pageCount > 0, let output = PDFDocument(data: originalData) else {
            return CompressionResult(document: document,
                                     originalByteCount: originalData.count,
                                     compressedByteCount: originalData.count,
                                     recompressedPageCount: 0)
        }

        var recompressedPages = 0
        for pageIndex in 0..<output.pageCount {
            guard let page = output.page(at: pageIndex) else { continue }

            // Keep whichever version is smaller. Re-encoding can lose: a page that
            // is already a low-resolution JPEG comes back heavier, and a tool that
            // hands back a bigger file has failed at the one thing it promised.
            if let compressedPage = self.recompressedPage(page, preset: preset),
               self.byteCount(of: compressedPage) < self.byteCount(of: page) {
                output.removePage(at: pageIndex)
                output.insert(compressedPage, at: pageIndex)
                recompressedPages += 1
            }
            progress?(Double(pageIndex + 1) / Double(output.pageCount))
        }

        // Nothing was touched: report the original size instead of the size of a
        // round-tripped copy, which differs for reasons the user did not ask for.
        let compressedCount = recompressedPages == 0
            ? originalData.count
            : (output.dataRepresentation()?.count ?? originalData.count)
        return CompressionResult(document: output,
                                 originalByteCount: originalData.count,
                                 compressedByteCount: compressedCount,
                                 recompressedPageCount: recompressedPages)
    }

    /// Returns a re-encoded page, or nil when the page should be kept as it is.
    ///
    /// Like `PdfRedactUtility`, this goes bitmap → JPEG → PDF context rather than
    /// through `PDFPage(image:)`, which renders black pages under `draw`.
    private static func recompressedPage(_ page: PDFPage, preset: CompressionPreset) -> PDFPage? {
        guard self.pageIsWorthRecompressing(page) else { return nil }

        let mediaBox = page.bounds(for: .mediaBox)
        // `bounds(for:)` ignores /Rotate while `draw(with:to:)` applies it, so the
        // canvas is sized on the rotated (as-displayed) geometry.
        let isQuarterTurned = abs(page.rotation) % 180 != 0
        let pageSize = isQuarterTurned
            ? CGSize(width: mediaBox.height, height: mediaBox.width)
            : mediaBox.size
        guard pageSize.width > 0, pageSize.height > 0 else { return nil }

        // The page keeps its physical size; only the pixels behind it shrink. The
        // render scale is what the preset really controls — quality alone barely
        // dents a 4000 px scan. Never upscale a page that is already small.
        let longestSide = max(pageSize.width, pageSize.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = max(min(preset.maxPixelSize / longestSide, 2.0), 0.1)
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: pageSize, format: format).image { context in
            let cgContext = context.cgContext
            // PDF pages carry no background: without this, anything the document
            // never painted comes out black once the bitmap is opaque.
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: pageSize))
            cgContext.translateBy(x: 0, y: pageSize.height)
            cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: cgContext)
        }

        let compressedImage = image.jpegData(compressionQuality: preset.jpegQuality)
            .flatMap { UIImage(data: $0) } ?? image

        let pageRect = CGRect(origin: .zero, size: pageSize)
        let data = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            context.beginPage()
            compressedImage.draw(in: pageRect)
        }
        return PDFDocument(data: data)?.page(at: 0)
    }

    /// Weight of a single page, measured by putting it in a document of its own.
    /// Not free, but the only honest way to compare two versions of a page.
    private static func byteCount(of page: PDFPage) -> Int {
        // Through the page's bytes, not `page.copy()`. A copied page leaves its
        // images behind, and this measured the leftovers: 841 bytes for a page
        // that weighs 1.6 MB, in the test next to this. Every decision the tool
        // makes — is this already as small as it gets, is the result worth
        // offering — compared two numbers that were both about nothing.
        guard let copy = PDFUtility.detachedPage(from: page) else { return .max }
        let document = PDFDocument()
        document.insert(copy, at: 0)
        return document.dataRepresentation()?.count ?? .max
    }

    /// True for the pages that carry pixels: a scan (no extractable text) or a
    /// page dominated by a high-resolution image. Everything else stays vector.
    static func pageIsWorthRecompressing(_ page: PDFPage) -> Bool {
        let hasText = !(page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !hasText || PDFUtility.pageIsImageHeavy(page)
    }
}

extension Int {

    /// "2,4 MB" — file sizes in the user's locale and units.
    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
