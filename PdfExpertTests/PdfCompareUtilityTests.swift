//
//  PdfCompareUtilityTests.swift
//  PdfExpertTests
//
//  Comparing two documents has three parts that can each be wrong on their own:
//  aligning the pages, diffing the words, and spotting the areas that render
//  differently. Each is exercised here.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfCompareUtilityTests: XCTestCase {

    private static let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)

    private func makeDocument(pageTexts: [String], drawAtTop: Bool = true) -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: Self.pageBounds).pdfData { context in
            for text in pageTexts {
                context.beginPage()
                let y: CGFloat = drawAtTop ? 40 : Self.pageBounds.height - 120
                (text as NSString).draw(at: CGPoint(x: 40, y: y),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    // MARK: - Text diff

    func testIdenticalTextHasNoChanges() {
        XCTAssertTrue(PdfCompareUtility.textDiff(left: "the tenant agrees to the terms",
                                                 right: "the tenant agrees to the terms").isEmpty)
    }

    func testReplacedWordIsReportedAsRemovedAndAdded() {
        let changes = PdfCompareUtility.textDiff(left: "rent is 900 euro per month",
                                                 right: "rent is 1200 euro per month")
        XCTAssertEqual(changes.count, 2)
        XCTAssertTrue(changes.contains(TextChange(kind: .removed, text: "900")))
        XCTAssertTrue(changes.contains(TextChange(kind: .added, text: "1200")))
    }

    /// Consecutive words of the same kind are reported as one run, not word by word.
    func testConsecutiveInsertionsAreGroupedIntoOneChange() {
        let changes = PdfCompareUtility.textDiff(left: "the parties agree",
                                                 right: "the parties hereby fully agree")
        XCTAssertEqual(changes, [TextChange(kind: .added, text: "hereby fully")])
    }

    func testDeletionAtTheEndIsReported() {
        let changes = PdfCompareUtility.textDiff(left: "clause one clause two",
                                                 right: "clause one")
        XCTAssertEqual(changes, [TextChange(kind: .removed, text: "clause two")])
    }

    func testDiffIgnoresLineBreaksAndExtraSpacing() {
        XCTAssertTrue(PdfCompareUtility.textDiff(left: "one two\nthree",
                                                 right: "one   two three").isEmpty)
    }

    // MARK: - Page alignment

    func testAlignmentPairsIdenticalDocumentsOneToOne() {
        let document = self.makeDocument(pageTexts: ["alpha page", "beta page", "gamma page"])
        let pairs = PdfCompareUtility.alignPages(left: document, right: document)
        XCTAssertEqual(pairs.count, 3)
        XCTAssertEqual(pairs.map(\.left), [0, 1, 2])
        XCTAssertEqual(pairs.map(\.right), [0, 1, 2])
    }

    /// The point of aligning at all: a page inserted at the front must not make
    /// every following page look rewritten.
    func testInsertedPageShiftsNothingElse() {
        let left = self.makeDocument(pageTexts: ["alpha page", "beta page"])
        let right = self.makeDocument(pageTexts: ["brand new page", "alpha page", "beta page"])

        let pairs = PdfCompareUtility.alignPages(left: left, right: right)
        XCTAssertEqual(pairs.count, 3)
        XCTAssertNil(pairs[0].left, "the new page exists only on the right")
        XCTAssertEqual(pairs[0].right, 0)
        XCTAssertEqual(pairs[1].left, 0)
        XCTAssertEqual(pairs[1].right, 1)
        XCTAssertEqual(pairs[2].left, 1)
        XCTAssertEqual(pairs[2].right, 2)
    }

    func testRemovedPageIsReportedAsRemoved() {
        let left = self.makeDocument(pageTexts: ["alpha page", "beta page", "gamma page"])
        let right = self.makeDocument(pageTexts: ["alpha page", "gamma page"])

        let result = PdfCompareUtility.compare(left: left, right: right)
        XCTAssertEqual(result.removedPageCount, 1)
        XCTAssertEqual(result.addedPageCount, 0)
        XCTAssertTrue(result.hasDifferences)
    }

    // MARK: - Whole comparison

    func testIdenticalDocumentsReportNoDifferences() {
        let document = self.makeDocument(pageTexts: ["alpha page", "beta page"])
        let copy = PDFDocument(data: document.dataRepresentation() ?? Data()) ?? PDFDocument()

        let result = PdfCompareUtility.compare(left: document, right: copy)
        XCTAssertFalse(result.hasDifferences)
        XCTAssertTrue(result.changedPages.isEmpty)
    }

    func testChangedWordIsFoundOnTheRightPage() {
        let left = self.makeDocument(pageTexts: ["untouched page", "rent is 900 euro"])
        let right = self.makeDocument(pageTexts: ["untouched page", "rent is 1200 euro"])

        let result = PdfCompareUtility.compare(left: left, right: right)
        XCTAssertEqual(result.changedPages.count, 1)
        let page = try? XCTUnwrap(result.changedPages.first)
        XCTAssertEqual(page?.rightPageIndex, 1)
        XCTAssertTrue(page?.textChanges.contains(TextChange(kind: .added, text: "1200")) == true)
    }

    func testProgressReachesOne() {
        let left = self.makeDocument(pageTexts: ["one", "two"])
        let right = self.makeDocument(pageTexts: ["one", "two"])
        var reported: [Double] = []
        _ = PdfCompareUtility.compare(left: left, right: right) { reported.append($0) }
        XCTAssertEqual(reported.last ?? 0, 1.0, accuracy: 0.0001)
    }

    // MARK: - Visual diff

    func testVisualDiffFlagsBothEndsWhenContentMoves() throws {
        let left = self.makeDocument(pageTexts: ["Signed"])
        let right = self.makeDocument(pageTexts: ["Signed"], drawAtTop: false)

        let leftPage = try XCTUnwrap(left.page(at: 0))
        let rightPage = try XCTUnwrap(right.page(at: 0))
        let visual = PdfCompareUtility.visualDiff(left: leftPage, right: rightPage)

        XCTAssertGreaterThan(visual.fraction, 0, "moving the text must light up some cells")
        let rows = self.changedRows(of: visual.cells)
        XCTAssertTrue(rows.contains { $0 < rows.count / 2 || $0 < 8 }, "the text left the top")
        XCTAssertTrue(rows.contains { $0 > 30 }, "and arrived near the bottom")
    }

    /// The grid is read top-down by the overlay that draws it, so row 0 has to be
    /// the top of the page — an inverted grid would highlight the wrong areas.
    func testVisualDiffGridStartsAtTheTopOfThePage() throws {
        let withText = self.makeDocument(pageTexts: ["Header only"])
        let blank = self.makeDocument(pageTexts: [""])

        let visual = PdfCompareUtility.visualDiff(left: try XCTUnwrap(withText.page(at: 0)),
                                                  right: try XCTUnwrap(blank.page(at: 0)))
        let rows = self.changedRows(of: visual.cells)
        XCTAssertFalse(rows.isEmpty)
        let totalRows = visual.cells.count / PdfCompareUtility.visualGridColumns
        XCTAssertTrue(rows.allSatisfy { $0 < totalRows / 2 },
                      "text drawn at the top must only light up rows in the upper half, got \(rows)")
    }

    private func changedRows(of cells: [Bool]) -> [Int] {
        let columns = PdfCompareUtility.visualGridColumns
        return cells.indices.filter { cells[$0] }.map { $0 / columns }
    }

    func testVisualDiffOfIdenticalPagesIsQuiet() throws {
        let document = self.makeDocument(pageTexts: ["Signed"])
        let page = try XCTUnwrap(document.page(at: 0))
        let visual = PdfCompareUtility.visualDiff(left: page, right: page)
        XCTAssertEqual(visual.fraction, 0, accuracy: 0.0001)
    }
}
