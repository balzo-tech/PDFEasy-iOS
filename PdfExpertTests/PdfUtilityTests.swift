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

    // MARK: - Extract pages

    /// Builds a PDF where page i carries the text "PageContent-i" (0-based), so an
    /// extracted document's pages can be traced back to their source via `page.string`.
    private func makeMultiPageTextPdf(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        for index in 0..<pageCount {
            let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
                context.beginPage()
                ("PageContent-\(index)" as NSString).draw(at: CGPoint(x: 50, y: 50),
                                                          withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
            if let pageDocument = PDFDocument(data: data), let page = pageDocument.page(at: 0) {
                document.insert(page, at: document.pageCount)
            }
        }
        return document
    }

    private func pageIdentifier(_ document: PDFDocument, _ index: Int) -> String {
        (document.page(at: index)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A single range yields exactly that slice, in order.
    func testExtractPagesSingleRange() {
        let document = makeMultiPageTextPdf(pageCount: 5)
        let result = PDFUtility.extractPages(fromDocument: document, pageRanges: [1...3])
        XCTAssertEqual(result.pageCount, 3)
        XCTAssertTrue(pageIdentifier(result, 0).contains("PageContent-1"))
        XCTAssertTrue(pageIdentifier(result, 1).contains("PageContent-2"))
        XCTAssertTrue(pageIdentifier(result, 2).contains("PageContent-3"))
    }

    /// Multiple ranges are concatenated into one document, in range order.
    func testExtractPagesMultipleRangesMergedInOrder() {
        let document = makeMultiPageTextPdf(pageCount: 6)
        let result = PDFUtility.extractPages(fromDocument: document, pageRanges: [0...1, 4...5])
        XCTAssertEqual(result.pageCount, 4)
        XCTAssertTrue(pageIdentifier(result, 0).contains("PageContent-0"))
        XCTAssertTrue(pageIdentifier(result, 1).contains("PageContent-1"))
        XCTAssertTrue(pageIdentifier(result, 2).contains("PageContent-4"))
        XCTAssertTrue(pageIdentifier(result, 3).contains("PageContent-5"))
    }

    /// Overlapping ranges duplicate the shared pages (same per-range semantics as split).
    func testExtractPagesOverlappingRangesDuplicatePages() {
        let document = makeMultiPageTextPdf(pageCount: 4)
        let result = PDFUtility.extractPages(fromDocument: document, pageRanges: [0...2, 1...3])
        XCTAssertEqual(result.pageCount, 6)
        XCTAssertTrue(pageIdentifier(result, 0).contains("PageContent-0"))
        XCTAssertTrue(pageIdentifier(result, 1).contains("PageContent-1"))
        XCTAssertTrue(pageIdentifier(result, 2).contains("PageContent-2"))
        XCTAssertTrue(pageIdentifier(result, 3).contains("PageContent-1"))
        XCTAssertTrue(pageIdentifier(result, 4).contains("PageContent-2"))
        XCTAssertTrue(pageIdentifier(result, 5).contains("PageContent-3"))
    }

    /// Out-of-order ranges preserve the given order (not sorted by page index).
    func testExtractPagesOutOfOrderRangesPreserveGivenOrder() {
        let document = makeMultiPageTextPdf(pageCount: 5)
        let result = PDFUtility.extractPages(fromDocument: document, pageRanges: [3...4, 0...1])
        XCTAssertEqual(result.pageCount, 4)
        XCTAssertTrue(pageIdentifier(result, 0).contains("PageContent-3"))
        XCTAssertTrue(pageIdentifier(result, 1).contains("PageContent-4"))
        XCTAssertTrue(pageIdentifier(result, 2).contains("PageContent-0"))
        XCTAssertTrue(pageIdentifier(result, 3).contains("PageContent-1"))
    }

    // MARK: - Rotation

    /// Clockwise rotation must cycle 0 → 90 → 180 → 270 → 0.
    func testRotatePageCyclesClockwise() {
        let document = makePdf(pageCount: 1)
        guard let page = document.page(at: 0) else { return XCTFail("missing page") }
        XCTAssertEqual(page.rotation, 0)
        let expected = [90, 180, 270, 0]
        for value in expected {
            PDFUtility.rotatePage(page, clockwise: true)
            XCTAssertEqual(page.rotation, value)
        }
    }

    /// Counter-clockwise rotation must cycle 0 → 270 → 180 → 90 → 0 (always normalized
    /// into the [0, 360) range, never negative).
    func testRotatePageCyclesCounterClockwise() {
        let document = makePdf(pageCount: 1)
        guard let page = document.page(at: 0) else { return XCTFail("missing page") }
        XCTAssertEqual(page.rotation, 0)
        let expected = [270, 180, 90, 0]
        for value in expected {
            PDFUtility.rotatePage(page, clockwise: false)
            XCTAssertEqual(page.rotation, value)
        }
    }

    /// The rotation is stored in the page's /Rotate entry, so it must survive a
    /// serialization round-trip.
    func testRotationSurvivesDataRoundTrip() {
        let document = makePdf(pageCount: 1)
        guard let page = document.page(at: 0) else { return XCTFail("missing page") }
        PDFUtility.rotatePage(page, clockwise: true) // 90
        guard let data = document.dataRepresentation(),
              let reloaded = PDFDocument(data: data),
              let reloadedPage = reloaded.page(at: 0) else {
            return XCTFail("round-trip failed")
        }
        XCTAssertEqual(reloadedPage.rotation, 90,
                       "rotation must persist through dataRepresentation() round-trip")
    }

    /// A portrait page rotated 90° must render as a landscape thumbnail (the full
    /// media-box branch swaps width/height for quarter-turn rotations).
    func testGeneratePdfThumbnailRotatedPageIsLandscape() {
        let document = makePdf(pageCount: 1) // portrait 200 x 300
        guard let page = document.page(at: 0) else { return XCTFail("missing page") }
        PDFUtility.rotatePage(page, clockwise: true) // 90
        guard let image = PDFUtility.generatePdfThumbnail(pdfDocument: document,
                                                          size: nil,
                                                          forPageIndex: 0) else {
            return XCTFail("expected a thumbnail")
        }
        XCTAssertGreaterThan(image.size.width, image.size.height,
                             "a rotated portrait page should produce a landscape thumbnail")
    }

    /// applyPostProcess with margins + compression on a 90°-rotated portrait page must
    /// keep the rotated aspect (a wider-than-tall output page).
    func testApplyPostProcessRotatedPageKeepsRotatedAspect() {
        let document = makePdf(pageCount: 1) // portrait 200 x 300
        guard let page = document.page(at: 0) else { return XCTFail("missing page") }
        PDFUtility.rotatePage(page, clockwise: true) // 90
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .mediumMargins,
                                                 compression: .high)
        guard let resultPage = result.page(at: 0) else { return XCTFail("missing result page") }
        let size = resultPage.bounds(for: .mediaBox).size
        XCTAssertGreaterThan(size.width, size.height,
                             "a rotated portrait page must stay landscape after post-process")
    }
}
