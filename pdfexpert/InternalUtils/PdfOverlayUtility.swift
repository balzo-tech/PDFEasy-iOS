//
//  PdfOverlayUtility.swift
//  PdfExpert
//
//  Shared drawing utility for stamping overlays (page numbers, watermarks) onto a
//  PDF. It rebuilds every page by re-drawing the original page content into a fresh
//  `UIGraphicsPDFRenderer` context and then painting the overlay on top — the same
//  vector-preserving redraw the cleanup utilities share.
//
//  Trade-off (identical to the share post-process): the redraw *flattens*
//  annotations. Existing signatures / free-text stay visible but stop being
//  editable, and form widgets lose their interactivity — the page becomes a plain
//  content stream. Selectable vector text is preserved (pages are drawn into a PDF
//  context, never rasterized), so extraction/search keep working.
//
//  Never uses `PDFPage(image:)`: that API renders black pages (see the note on
//  `UIImage.pdfPage()` in `PdfUtility.swift`). Overlay text is drawn with UIKit
//  `NSAttributedString` APIs, which work natively inside the renderer closure
//  (top-left, y-down coordinates), exactly like the `UIImage.pdfPage()` extension.
//

import Foundation
import UIKit
import PDFKit

// MARK: - Page numbers

enum PageNumberPosition: String, CaseIterable {
    case topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight
}

enum PageNumberFormat: String, CaseIterable {
    case simple  // "1"
    case ofTotal // "1 of N"
}

struct PageNumberStyle {
    var position = PageNumberPosition.bottomCenter
    var format = PageNumberFormat.simple
    var fontSize: CGFloat = 12
}

// MARK: - Watermark

enum WatermarkLayout: String, CaseIterable {
    case diagonal, horizontal
}

struct WatermarkStyle {
    var text: String
    var opacity: CGFloat = 0.3
    var layout = WatermarkLayout.diagonal
    var fontSize: CGFloat = 48
    // TODO: add an optional `image: UIImage?` here for a future image watermark
    // (draw it centered/tiled instead of `text` when provided).
}

class PdfOverlayUtility {

    /// Distance (pt) between the page-number text and the page edges it anchors to.
    private static let pageNumberInset: CGFloat = 20

    // MARK: - Public entry points

    /// Returns a new document with a page number stamped on every page. The input
    /// document is never mutated. Returns `nil` only if the redraw fails entirely.
    static func addPageNumbers(to document: PDFDocument, style: PageNumberStyle) -> PDFDocument? {
        let total = document.pageCount
        return redrawPages(of: document) { _, pageIndex, pageSize in
            let text: String
            switch style.format {
            case .simple:
                text = "\(pageIndex + 1)"
            case .ofTotal:
                // Interpolated, localized "1 of N". The catalog entry can reorder
                // the operands per language (e.g. Italian "1 di N").
                text = String(localized: "\(pageIndex + 1) of \(total)",
                              comment: "Page number label, e.g. '1 of 10'")
            }
            Self.drawPageNumber(text,
                                pageSize: pageSize,
                                fontSize: style.fontSize,
                                position: style.position)
        }
    }

    /// Returns a new document with a watermark stamped (centered) on every page.
    /// The input document is never mutated. Returns `nil` only if the redraw fails.
    static func addWatermark(to document: PDFDocument, style: WatermarkStyle) -> PDFDocument? {
        return redrawPages(of: document) { cg, _, pageSize in
            Self.drawWatermark(style: style, in: cg, pageSize: pageSize)
        }
    }

    // MARK: - Core redraw

    /// Rebuilds every page of `document` into a brand-new `PDFDocument`: the
    /// original page content is drawn first (flattened but vector-preserving), then
    /// `overlay` is invoked to paint on top in UIKit (top-left, y-down) coordinates.
    ///
    /// - The source document is treated as read-only; the result is always a fresh
    ///   document built from the renderer's output data.
    /// - A 0-page document yields a valid, empty document (the loop is simply skipped).
    ///
    /// Shared with `PdfCleanupUtility` (flatten / invert colors), which needs exactly
    /// this rotation-aware, vector-preserving rebuild.
    ///
    /// `underlay` paints *behind* the page content. PDF pages have no background —
    /// unpainted areas are transparent — so any effect that has to compose against the
    /// page (colour inversion, for one) needs an opaque backdrop laid down first.
    static func redrawPages(of document: PDFDocument,
                            underlay: ((CGContext, _ pageSize: CGSize) -> Void)? = nil,
                            overlay: (CGContext, _ pageIndex: Int, _ pageSize: CGSize) -> Void) -> PDFDocument? {

        let newDocument = PDFDocument()

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            let pageRect = page.bounds(for: .mediaBox)

            // PDFKit's `bounds(for:)` ignores /Rotate, so swap width/height for
            // quarter-turn rotations to size the canvas as it renders (landscape).
            // `page.draw(with:to:)` applies the rotation itself.
            let isQuarterTurned = abs(page.rotation) % 180 != 0
            let pageSize = isQuarterTurned
                ? CGSize(width: pageRect.height, height: pageRect.width)
                : pageRect.size

            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
            let data = renderer.pdfData { ctx in
                ctx.beginPage()
                let cg = ctx.cgContext

                // 0) Optional backdrop, painted before anything else.
                underlay?(cg, pageSize)

                // 1) Draw the original page content. Flip into PDF (bottom-left,
                //    y-up) space, honoring the media-box origin.
                cg.saveGState()
                cg.translateBy(x: -pageRect.origin.x, y: pageSize.height - pageRect.origin.y)
                cg.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()

                // 2) Paint the overlay in the renderer's native UIKit coordinates.
                overlay(cg, pageIndex, pageSize)
            }

            if let pageDocument = PDFDocument(data: data), let newPage = pageDocument.page(at: 0) {
                newDocument.insert(newPage, at: newDocument.pageCount)
            }
        }

        return newDocument
    }

    // MARK: - Drawing helpers

    /// Draws the page-number `text` anchored to `position`, inset from the page
    /// edges. UIKit top-left coordinates, so `NSAttributedString.draw(in:)` renders
    /// upright inside the renderer closure.
    private static func drawPageNumber(_ text: String,
                                       pageSize: CGSize,
                                       fontSize: CGFloat,
                                       position: PageNumberPosition) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.darkGray
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let inset = Self.pageNumberInset

        let x: CGFloat
        switch position {
        case .topLeft, .bottomLeft:
            x = inset
        case .topCenter, .bottomCenter:
            x = (pageSize.width - textSize.width) / 2
        case .topRight, .bottomRight:
            x = pageSize.width - textSize.width - inset
        }

        let y: CGFloat
        switch position {
        case .topLeft, .topCenter, .topRight:
            y = inset
        case .bottomLeft, .bottomCenter, .bottomRight:
            y = pageSize.height - textSize.height - inset
        }

        attributed.draw(in: CGRect(origin: CGPoint(x: x, y: y), size: textSize))
    }

    /// Draws a single centered watermark run. `.diagonal` rotates the context −45°
    /// around the page center; opacity is carried by the text color's alpha.
    private static func drawWatermark(style: WatermarkStyle, in cg: CGContext, pageSize: CGSize) {
        let text = style.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: style.fontSize),
            .foregroundColor: UIColor.darkGray.withAlphaComponent(style.opacity)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()

        cg.saveGState()
        // Rotate about the page center, then draw the run centered on that origin.
        cg.translateBy(x: pageSize.width / 2, y: pageSize.height / 2)
        if style.layout == .diagonal {
            cg.rotate(by: -CGFloat.pi / 4) // −45°
        }
        attributed.draw(in: CGRect(x: -textSize.width / 2,
                                   y: -textSize.height / 2,
                                   width: textSize.width,
                                   height: textSize.height))
        cg.restoreGState()
    }
}
