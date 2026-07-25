//
//  PdfCleanupUtilityTests.swift
//  PdfExpertTests
//
//  Covers the document-hygiene tools: blank-page removal, flatten and invert colors.
//  The recurring assertion across all three is that text stays extractable — these
//  operations rebuild every page, and a rasterizing implementation would silently
//  break both text selection and the archive's full-text search.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfCleanupUtilityTests: XCTestCase {

    // MARK: - Fixtures

    private static let pageBounds = CGRect(x: 0, y: 0, width: 400, height: 600)

    /// Builds a document whose pages are described by `pages`: a non-nil string draws
    /// that text, nil leaves the page blank.
    private func makeDocument(pages: [String?]) -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: Self.pageBounds).pdfData { context in
            for text in pages {
                context.beginPage()
                if let text = text {
                    (text as NSString).draw(at: CGPoint(x: 40, y: 40),
                                            withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
                }
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    private func makeDocumentWithAnnotation() -> PDFDocument {
        let document = self.makeDocument(pages: ["Body text"])
        guard let page = document.page(at: 0) else { return document }
        let annotation = PDFAnnotation(bounds: CGRect(x: 100, y: 300, width: 200, height: 40),
                                       forType: .freeText,
                                       withProperties: nil)
        annotation.contents = "Annotated"
        annotation.font = UIFont.systemFont(ofSize: 18)
        annotation.color = .yellow
        page.addAnnotation(annotation)
        return document
    }

    // MARK: - Blank pages

    func testBlankPageIndexesFindsOnlyEmptyPages() {
        let document = self.makeDocument(pages: ["First", nil, "Third", nil])
        XCTAssertEqual(PdfCleanupUtility.blankPageIndexes(in: document), [1, 3])
    }

    func testRemoveBlankPagesDropsThemAndKeepsTheRest() throws {
        let document = self.makeDocument(pages: ["First", nil, "Third"])
        let result = PdfCleanupUtility.removeBlankPages(from: document)
        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(result.document.pageCount, 2)
        let text = PDFUtility.extractText(from: result.document)
        XCTAssertTrue(text.contains("First"))
        XCTAssertTrue(text.contains("Third"))
    }

    func testRemoveBlankPagesIsANoOpWhenThereAreNone() {
        let document = self.makeDocument(pages: ["First", "Second"])
        let result = PdfCleanupUtility.removeBlankPages(from: document)
        XCTAssertEqual(result.removedCount, 0)
        XCTAssertEqual(result.document.pageCount, 2)
    }

    /// An all-blank document must come back untouched: emptying the user's file would
    /// be the worst possible outcome of a tool meant to tidy it.
    func testRemoveBlankPagesNeverEmptiesTheDocument() {
        let document = self.makeDocument(pages: [nil, nil, nil])
        let result = PdfCleanupUtility.removeBlankPages(from: document)
        XCTAssertEqual(result.removedCount, 0)
        XCTAssertEqual(result.document.pageCount, 3)
    }

    func testRemoveBlankPagesLeavesTheSourceDocumentUntouched() {
        let document = self.makeDocument(pages: ["First", nil])
        _ = PdfCleanupUtility.removeBlankPages(from: document)
        XCTAssertEqual(document.pageCount, 2, "the input document must not be mutated")
    }

    // MARK: - Flatten

    func testFlattenRemovesAnnotationsAndKeepsText() throws {
        let document = self.makeDocumentWithAnnotation()
        XCTAssertFalse(document.page(at: 0)?.annotations.isEmpty ?? true,
                       "fixture should carry an annotation")

        let flattened = try XCTUnwrap(PdfCleanupUtility.flatten(document))
        XCTAssertEqual(flattened.pageCount, document.pageCount)
        XCTAssertTrue(flattened.page(at: 0)?.annotations.isEmpty ?? false,
                      "annotations must be baked into the page content")
        XCTAssertTrue(PDFUtility.extractText(from: flattened).contains("Body text"),
                      "page text must stay selectable")
    }

    // MARK: - Invert colors

    func testInvertColorsKeepsPagesAndSelectableText() throws {
        let document = self.makeDocument(pages: ["Readable", "Pages"])
        let inverted = try XCTUnwrap(PdfCleanupUtility.invertColors(of: document))
        XCTAssertEqual(inverted.pageCount, 2)
        let text = PDFUtility.extractText(from: inverted)
        XCTAssertTrue(text.contains("Readable"))
        XCTAssertTrue(text.contains("Pages"))
    }

    /// The point of the tool: a white page must come back dark.
    func testInvertColorsDarkensAWhitePage() throws {
        let document = self.makeDocument(pages: ["Readable"])
        let inverted = try XCTUnwrap(PdfCleanupUtility.invertColors(of: document))
        let page = try XCTUnwrap(inverted.page(at: 0))
        XCTAssertGreaterThan(PDFUtility.pageInkRatio(page), 0.9,
                             "an inverted white page should read as almost entirely inked")
    }

    func testInvertColorsSurvivesEmptyDocument() {
        let inverted = PdfCleanupUtility.invertColors(of: PDFDocument())
        XCTAssertEqual(inverted?.pageCount, 0)
    }
}
