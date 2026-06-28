//
//  PdfUtilityTests.swift
//  PdfExpertTests
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfUtilityTests: XCTestCase {

    /// Builds an in-memory PDF made of `pageCount` blank raster pages.
    private func makePdf(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()
        let size = CGSize(width: 200, height: 300)
        for _ in 0..<pageCount {
            let image = UIGraphicsImageRenderer(size: size).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            if let page = PDFPage(image: image) {
                document.insert(page, at: document.pageCount)
            }
        }
        return document
    }

    /// The no-op path (no margins, no compression) returns an equivalent document
    /// and must not trap on the force-unwraps that used to live on that branch.
    func testApplyPostProcessNoOpPreservesPageCount() {
        let document = makePdf(pageCount: 3)
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .noMargins,
                                                 compression: .noCompression)
        XCTAssertEqual(result.pageCount, 3)
    }

    /// The processing path (margins + compression) must keep every page.
    func testApplyPostProcessWithMarginsKeepsPages() {
        let document = makePdf(pageCount: 2)
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .mediumMargins,
                                                 compression: .high)
        XCTAssertEqual(result.pageCount, 2)
    }

    /// An empty document must not crash: the `pageCount > 0` guard and the removed
    /// `dataRepresentation()!` force-unwrap are what this exercises. Reaching the
    /// assertion at all is the guarantee; PDFKit round-trips an empty document into
    /// a single blank page, so the page count is only loosely bounded here.
    func testApplyPostProcessEmptyDocumentDoesNotCrash() {
        let document = PDFDocument()
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .noMargins,
                                                 compression: .noCompression)
        XCTAssertLessThanOrEqual(result.pageCount, 1)
    }

    /// Builds a PDF page containing real, selectable text.
    private func makeTextPdf(text: String) -> PDFDocument {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            (text as NSString).draw(at: CGPoint(x: 50, y: 50),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    /// Margins must be drawn into a PDF context so the text stays selectable (A2):
    /// with the old rasterizing implementation the result page carried no text.
    func testApplyPostProcessKeepsTextSelectableWithMargins() {
        let document = makeTextPdf(text: "Hello selectable world")
        XCTAssertTrue((document.page(at: 0)?.string ?? "").contains("selectable"),
                      "fixture should have extractable text")
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .mediumMargins,
                                                 compression: .noCompression)
        let resultText = result.page(at: 0)?.string ?? ""
        XCTAssertTrue(resultText.contains("selectable"),
                      "text must survive margins, got: \(resultText)")
    }

    /// A text page must stay vector even when compression is requested (A2b):
    /// only image-only / image-heavy pages get rasterized.
    func testApplyPostProcessKeepsTextPageVectorUnderCompression() {
        let document = makeTextPdf(text: "Keep me vector")
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .noMargins,
                                                 compression: .high)
        let resultText = result.page(at: 0)?.string ?? ""
        XCTAssertTrue(resultText.contains("vector"),
                      "a text page must stay vector under compression, got: \(resultText)")
    }

    /// Full-text indexing: a text PDF must yield its page text.
    func testExtractTextReturnsPageText() {
        let document = makeTextPdf(text: "Hello indexable world")
        XCTAssertTrue(PDFUtility.extractText(from: document).contains("indexable"),
                      "extractText should return the page text")
    }

    /// An image-only document (no extractable text) must yield an empty string.
    func testExtractTextEmptyForImageOnlyDocument() {
        let document = makePdf(pageCount: 1)
        XCTAssertTrue(PDFUtility.extractText(from: document)
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      "extractText should be empty for an image-only document")
    }
}
