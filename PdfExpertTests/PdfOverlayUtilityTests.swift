//
//  PdfOverlayUtilityTests.swift
//  PdfExpertTests
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfOverlayUtilityTests: XCTestCase {

    /// Builds a multi-page PDF where each page carries real, selectable (vector)
    /// text. Mirrors the `makeTextPdf` fixtures in the other utility test suites.
    private func makeTextPdf(pageTexts: [String]) -> PDFDocument {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for text in pageTexts {
                context.beginPage()
                (text as NSString).draw(at: CGPoint(x: 50, y: 50),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    private func makeTextPdf(text: String) -> PDFDocument {
        makeTextPdf(pageTexts: [text])
    }

    // MARK: - Page numbers

    /// The page-number text (`.simple` format) must appear on every page.
    func testPageNumbersSimpleAppearOnEveryPage() {
        let document = makeTextPdf(pageTexts: ["Alpha", "Bravo", "Charlie"])
        var style = PageNumberStyle()
        style.format = .simple
        let result = PdfOverlayUtility.addPageNumbers(to: document, style: style)
        for index in 0..<3 {
            let string = result?.page(at: index)?.string ?? ""
            XCTAssertTrue(string.contains("\(index + 1)"),
                          "page \(index) should contain its number, got: \(string)")
        }
    }

    /// The page-number text (`.ofTotal` format) must appear on every page,
    /// carrying both the current index and the total.
    func testPageNumbersOfTotalAppearOnEveryPage() {
        let document = makeTextPdf(pageTexts: ["Alpha", "Bravo", "Charlie"])
        var style = PageNumberStyle()
        style.format = .ofTotal
        let result = PdfOverlayUtility.addPageNumbers(to: document, style: style)
        for index in 0..<3 {
            let string = result?.page(at: index)?.string ?? ""
            XCTAssertTrue(string.contains("\(index + 1)"),
                          "page \(index) should contain its number, got: \(string)")
            XCTAssertTrue(string.contains("3"),
                          "page \(index) should contain the total, got: \(string)")
        }
    }

    /// Both operations must preserve the page count.
    func testPageCountPreservedForBothOperations() {
        let document = makeTextPdf(pageTexts: ["A", "B", "C"])
        let numbered = PdfOverlayUtility.addPageNumbers(to: document, style: PageNumberStyle())
        XCTAssertEqual(numbered?.pageCount, 3, "page numbering must keep the page count")
        let watermarked = PdfOverlayUtility.addWatermark(to: document, style: WatermarkStyle(text: "DRAFT"))
        XCTAssertEqual(watermarked?.pageCount, 3, "watermarking must keep the page count")
    }

    /// Existing vector text must survive the overlay redraw (stays extractable).
    func testExistingTextSurvivesOverlay() {
        let document = makeTextPdf(pageTexts: ["Selectable one", "Selectable two"])
        let numbered = PdfOverlayUtility.addPageNumbers(to: document, style: PageNumberStyle())
        XCTAssertTrue((numbered?.page(at: 0)?.string ?? "").contains("Selectable"),
                      "page 0 vector text must survive numbering")
        XCTAssertTrue((numbered?.page(at: 1)?.string ?? "").contains("Selectable"),
                      "page 1 vector text must survive numbering")

        let watermarked = PdfOverlayUtility.addWatermark(to: document, style: WatermarkStyle(text: "DRAFT"))
        XCTAssertTrue((watermarked?.page(at: 0)?.string ?? "").contains("Selectable"),
                      "vector text must survive watermarking")
    }

    /// The watermark text must appear on every page.
    func testWatermarkTextOnEveryPage() {
        let document = makeTextPdf(pageTexts: ["First", "Second"])
        let result = PdfOverlayUtility.addWatermark(to: document, style: WatermarkStyle(text: "CONFIDENTIAL"))
        for index in 0..<2 {
            let string = result?.page(at: index)?.string ?? ""
            XCTAssertTrue(string.contains("CONFIDENTIAL"),
                          "watermark must be present on page \(index), got: \(string)")
        }
    }

    /// An empty (0-page) document must not crash and must produce a valid, empty result.
    func testEmptyDocumentDoesNotCrash() {
        let numbered = PdfOverlayUtility.addPageNumbers(to: PDFDocument(), style: PageNumberStyle())
        XCTAssertEqual(numbered?.pageCount, 0, "numbering an empty document stays empty")
        let watermarked = PdfOverlayUtility.addWatermark(to: PDFDocument(), style: WatermarkStyle(text: "X"))
        XCTAssertEqual(watermarked?.pageCount, 0, "watermarking an empty document stays empty")
    }

    /// The input document must not be mutated by either operation.
    func testInputDocumentNotMutated() {
        let document = makeTextPdf(pageTexts: ["Only page"])
        _ = PdfOverlayUtility.addPageNumbers(to: document, style: PageNumberStyle())
        _ = PdfOverlayUtility.addWatermark(to: document, style: WatermarkStyle(text: "DRAFT"))
        let string = document.page(at: 0)?.string ?? ""
        XCTAssertEqual(document.pageCount, 1, "source page count must be unchanged")
        XCTAssertFalse(string.contains("DRAFT"), "source page must not gain the watermark")
    }

    /// A 90°-rotated portrait page must come out landscape (its rotated dimensions
    /// are preserved through the redraw) and still carry the page-number overlay.
    func testRotatedPageKeepsLandscapeDimensions() {
        let document = makeTextPdf(text: "Body") // portrait 400 x 600
        document.page(at: 0)?.rotation = 90
        XCTAssertEqual(document.page(at: 0)?.rotation, 90, "fixture should be rotated")

        let result = PdfOverlayUtility.addPageNumbers(to: document, style: PageNumberStyle())
        guard let page = result?.page(at: 0) else { return XCTFail("expected an output page") }

        let bounds = page.bounds(for: .mediaBox)
        XCTAssertGreaterThan(bounds.width, bounds.height,
                             "rotated page must come out landscape, got: \(bounds.size)")
        XCTAssertTrue((page.string ?? "").contains("1"),
                      "page-number overlay must be present on the rotated page")
    }
}
