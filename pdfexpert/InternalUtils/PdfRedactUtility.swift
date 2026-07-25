//
//  PdfRedactUtility.swift
//  PdfExpert
//
//  Secure redaction: the pages the user marked are **rasterized** with the boxes
//  painted on, so the text underneath is gone from the file — not merely hidden.
//
//  Black annotations (or a black rectangle drawn over live text) are the classic
//  redaction failure: any PDF editor removes the annotation, and text extraction and
//  copy/paste still return the "redacted" words. That is why nothing here draws over
//  the original content stream — a touched page is replaced by a flat image.
//
//  Pages the user did not touch are left exactly as they were, so a redaction on
//  page 1 does not cost the whole document its selectable text.
//

import Foundation
import UIKit
import PDFKit

/// A rectangle to black out.
///
/// `rect` is **normalized (0…1) against the page as displayed**, with the origin at the
/// top-left — the same space the UI draws in, so the view can hand over what it measured
/// without a coordinate conversion that would silently break on rotated pages.
struct RedactionBox: Identifiable, Equatable {
    let id: UUID
    let pageIndex: Int
    let rect: CGRect

    init(id: UUID = UUID(), pageIndex: Int, rect: CGRect) {
        self.id = id
        self.pageIndex = pageIndex
        self.rect = rect
    }
}

class PdfRedactUtility {

    /// Pixel density of the rasterized pages. 2× keeps the result legible without
    /// exploding the file size (the page is JPEG-compressed on the way in).
    static let defaultRenderScale: CGFloat = 2.0
    /// Matches `OcrUtility.defaultJpegQuality`: the redacted pages become images, and
    /// storing them lossless would bloat the Core Data blob.
    static let defaultJpegQuality: CGFloat = 0.8

    /// Returns a copy of `document` with every marked area permanently removed.
    /// Returns the input untouched when there is nothing to redact.
    static func redact(document: PDFDocument,
                       boxes: [RedactionBox],
                       renderScale: CGFloat = defaultRenderScale,
                       jpegQuality: CGFloat = defaultJpegQuality) -> PDFDocument? {
        guard !boxes.isEmpty else { return document }
        guard let redacted = document.dataRepresentation().flatMap({ PDFDocument(data: $0) }) else {
            return nil
        }

        let boxesByPage = Dictionary(grouping: boxes, by: { $0.pageIndex })
        for (pageIndex, pageBoxes) in boxesByPage {
            guard pageIndex >= 0, pageIndex < redacted.pageCount,
                  let page = redacted.page(at: pageIndex),
                  let flattenedPage = self.rasterizedPage(page,
                                                          boxes: pageBoxes,
                                                          renderScale: renderScale,
                                                          jpegQuality: jpegQuality) else { continue }
            redacted.removePage(at: pageIndex)
            redacted.insert(flattenedPage, at: pageIndex)
        }
        return redacted
    }

    /// The page as a flat image with the boxes burned in.
    ///
    /// Never `PDFPage(image:)` — that API renders black pages under `draw`; the bitmap
    /// is drawn into a PDF context instead.
    private static func rasterizedPage(_ page: PDFPage,
                                       boxes: [RedactionBox],
                                       renderScale: CGFloat,
                                       jpegQuality: CGFloat) -> PDFPage? {
        let mediaBox = page.bounds(for: .mediaBox)
        // `bounds(for:)` ignores /Rotate while `draw(with:to:)` applies it, so the canvas
        // is sized on the rotated (as-displayed) geometry — which is also the space the
        // normalized boxes were measured in.
        let isQuarterTurned = abs(page.rotation) % 180 != 0
        let pageSize = isQuarterTurned
            ? CGSize(width: mediaBox.height, height: mediaBox.width)
            : mediaBox.size
        guard pageSize.width > 0, pageSize.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = renderScale
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: pageSize, format: format).image { context in
            let cgContext = context.cgContext
            // PDF pages have no background; without this the areas the document never
            // painted would come out black once the page is made opaque.
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: pageSize))

            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: pageSize.height)
            cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: cgContext)
            cgContext.restoreGState()

            cgContext.setFillColor(UIColor.black.cgColor)
            for box in boxes {
                cgContext.fill(self.rect(for: box, pageSize: pageSize))
            }
        }

        // Re-encode through JPEG to keep the archived document from ballooning.
        let flattenedImage = image.jpegData(compressionQuality: jpegQuality)
            .flatMap { UIImage(data: $0) } ?? image

        let pageRect = CGRect(origin: .zero, size: pageSize)
        let data = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { context in
            context.beginPage()
            flattenedImage.draw(in: pageRect)
        }
        return PDFDocument(data: data)?.page(at: 0)
    }

    /// Normalized (top-left) box → point rect on the rendered page.
    static func rect(for box: RedactionBox, pageSize: CGSize) -> CGRect {
        CGRect(x: box.rect.origin.x * pageSize.width,
               y: box.rect.origin.y * pageSize.height,
               width: box.rect.width * pageSize.width,
               height: box.rect.height * pageSize.height)
    }
}
