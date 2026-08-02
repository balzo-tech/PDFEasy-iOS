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

    // MARK: - Document metadata

    /// The standard PDF metadata attributes must survive a `dataRepresentation()`
    /// round-trip. The metadata editor writes edits straight into
    /// `documentAttributes`, so this is what lets it persist without any schema
    /// change. Keywords are written as a `[String]` and may come back either as an
    /// array or as a single joined string, so the assertion tolerates both shapes.
    func testDocumentAttributesSurviveDataRoundTrip() {
        let document = makePdf(pageCount: 1)
        var attributes = document.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.titleAttribute] = "Round Trip Title"
        attributes[PDFDocumentAttribute.authorAttribute] = "Jane Author"
        attributes[PDFDocumentAttribute.subjectAttribute] = "Test Subject"
        attributes[PDFDocumentAttribute.creatorAttribute] = "PdfExpert Tests"
        attributes[PDFDocumentAttribute.keywordsAttribute] = ["alpha", "beta", "gamma"]
        document.documentAttributes = attributes

        guard let data = document.dataRepresentation(),
              let reloaded = PDFDocument(data: data) else {
            return XCTFail("round-trip failed")
        }
        let reloadedAttributes = reloaded.documentAttributes ?? [:]
        XCTAssertEqual(reloadedAttributes[PDFDocumentAttribute.titleAttribute] as? String,
                       "Round Trip Title")
        XCTAssertEqual(reloadedAttributes[PDFDocumentAttribute.authorAttribute] as? String,
                       "Jane Author")
        XCTAssertEqual(reloadedAttributes[PDFDocumentAttribute.subjectAttribute] as? String,
                       "Test Subject")
        XCTAssertEqual(reloadedAttributes[PDFDocumentAttribute.creatorAttribute] as? String,
                       "PdfExpert Tests")

        let keywordsValue = reloadedAttributes[PDFDocumentAttribute.keywordsAttribute]
        let keywordsText: String
        if let array = keywordsValue as? [String] {
            keywordsText = array.joined(separator: " ")
        } else if let string = keywordsValue as? String {
            keywordsText = string
        } else {
            return XCTFail("keywords missing after round-trip")
        }
        XCTAssertTrue(keywordsText.contains("alpha"), "got: \(keywordsText)")
        XCTAssertTrue(keywordsText.contains("beta"), "got: \(keywordsText)")
        XCTAssertTrue(keywordsText.contains("gamma"), "got: \(keywordsText)")
    }

    // MARK: - Blank-page detection

    /// A page drawn through `UIGraphicsPDFRenderer` with an optional drawing block.
    /// (Not `PDFPage(image:)` — that API renders black pages under `draw`.)
    private func makeVectorPage(drawing: ((CGContext) -> Void)? = nil) -> PDFPage? {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            drawing?(context.cgContext)
        }
        return PDFDocument(data: data)?.page(at: 0)
    }

    func testPageIsBlankDetectsEmptyPage() throws {
        let page = try XCTUnwrap(self.makeVectorPage())
        XCTAssertTrue(PDFUtility.pageIsBlank(page))
    }

    func testPageIsBlankRejectsPageWithText() throws {
        let document = self.makeTextPdf(text: "Not blank at all")
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertFalse(PDFUtility.pageIsBlank(page))
    }

    /// Text extraction alone would call an image-only page blank; the ink check is
    /// what keeps a scanned page out of the blank bucket.
    func testPageIsBlankRejectsGraphicsOnlyPage() throws {
        let page = try XCTUnwrap(self.makeVectorPage { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 300, height: 400))
        })
        XCTAssertEqual(page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", "",
                       "fixture must carry no extractable text")
        XCTAssertFalse(PDFUtility.pageIsBlank(page))
    }

    func testPageInkRatioGrowsWithCoverage() throws {
        let empty = try XCTUnwrap(self.makeVectorPage())
        let half = try XCTUnwrap(self.makeVectorPage { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        })
        XCTAssertLessThan(PDFUtility.pageInkRatio(empty), PDFUtility.blankPageInkThreshold)
        XCTAssertGreaterThan(PDFUtility.pageInkRatio(half), 0.4)
    }

    /// A few stray dark pixels (scanner speckle) must not save a page from being
    /// classified as blank.
    func testPageIsBlankToleratesSpeckle() throws {
        let page = try XCTUnwrap(self.makeVectorPage { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 10, y: 10, width: 2, height: 2))
        })
        XCTAssertTrue(PDFUtility.pageIsBlank(page))
    }

    // MARK: - What the user is told about a file that will not open

    /// A damaged file used to be reported as "Internal Error. Please try again
    /// later": the app took the blame for the file, and asked for a retry that
    /// could never work. The two cases must not share their wording again.
    func testAnUnreadableFileIsNotReportedAsAnInternalError() {
        let unreadable = PdfError.urlToPdfConversionError.errorDescription
        let internalError = PdfError.unknownError.errorDescription

        XCTAssertNotNil(unreadable)
        XCTAssertNotEqual(unreadable, internalError,
                          "a file that will not open is not an internal error")
        XCTAssertFalse(unreadable?.lowercased().contains("try again") ?? true,
                       "nothing is gained by retrying a damaged file")
    }
}
