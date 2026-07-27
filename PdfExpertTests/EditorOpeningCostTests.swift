//
//  EditorOpeningCostTests.swift
//  PdfExpertTests
//
//  What it costs to open a document in the editor — in time, and in memory.
//
//  Opening used to build two images per page synchronously inside `init`, and
//  again after every tool. On a text document that is free. On a scan it is not:
//  the cost is decoding the photograph inside each page, it was paid twice per
//  page whatever size comes out, and it measured **0.9s per page on a Mac**. A
//  twenty-page scan therefore froze the editor for eighteen seconds before it
//  drew anything — which from the outside is indistinguishable from an editor
//  whose buttons do not work, because for those eighteen seconds they do not.
//
//  The second half of the same story is memory: one full-size image per page is
//  about 2 MB, so the editor sat on ~100 MB for a fifty-page scan, nearly all of
//  it pages nobody was looking at. Now only the page on screen and its
//  neighbours are kept drawn.
//
//  These tests hold both lines: opening returns immediately, the pages arrive
//  afterwards, and what is held stays bounded however long the document is.
//

import XCTest
import PDFKit
import Factory
@testable import PdfExpert

final class EditorOpeningCostTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Container.shared.repository.register { OpeningRepositoryMock() }
        Container.shared.analyticsManager.register { OpeningAnalyticsMock() }
    }

    override func tearDown() {
        Container.shared.repository.reset()
        Container.shared.analyticsManager.reset()
        super.tearDown()
    }

    @MainActor
    func testOpeningAScanReturnsStraightAway() {
        let pdf = Pdf(pdfDocument: self.makeScan(pageCount: 10))

        let started = Date()
        let viewModel = self.makeViewModel(pdf: pdf)
        let elapsed = Date().timeIntervalSince(started)

        // Before the pages moved off the main thread this was about nine
        // seconds for ten pages, and the editor drew nothing until it was over.
        XCTAssertLessThan(elapsed, 1.0, "opening a ten-page scan blocked for \(elapsed)s")
        XCTAssertTrue(viewModel.isPreparingPages)
        // The count is known immediately even though the images are not: it is
        // what the page bar and the tool panel are sized from.
        XCTAssertEqual(viewModel.pageCount, 10)
    }

    @MainActor
    func testThePagesArriveOneAtATime() {
        let viewModel = self.makeViewModel(pdf: Pdf(pdfDocument: self.makeScan(pageCount: 10)))

        // The first page is what the reader is looking at, and it should not
        // wait for the tenth.
        let firstPageArrived = self.wait(upTo: 20) { viewModel.pages.count >= 1 }

        XCTAssertTrue(firstPageArrived, "no page was drawn")
        // Until every page is in, nothing is allowed to reorder or delete them.
        XCTAssertEqual(viewModel.canEditPages, !viewModel.isPreparingPages)
    }

    @MainActor
    func testAShortDocumentIsReadyAlmostImmediately() {
        let viewModel = self.makeViewModel(pdf: Pdf(pdfDocument: self.makeTextDocument(pageCount: 3)))

        XCTAssertTrue(self.wait(upTo: 10) { !viewModel.isPreparingPages })
        XCTAssertEqual(viewModel.pages.count, 3)
        XCTAssertTrue(viewModel.canEditPages)
    }

    // MARK: - What is kept in memory

    /// The point of the whole arrangement: a long document does not mean a long
    /// list of full-size images.
    @MainActor
    func testALongDocumentOnlyKeepsAFewPagesDrawn() {
        let viewModel = self.makeViewModel(pdf: Pdf(pdfDocument: self.makeTextDocument(pageCount: 40)))

        XCTAssertTrue(self.wait(upTo: 20) { !viewModel.isPreparingPages })
        XCTAssertTrue(self.wait(upTo: 10) { viewModel.pageImage(at: 0) != nil },
                      "the page being looked at was never drawn")

        XCTAssertEqual(viewModel.pages.count, 40)
        XCTAssertLessThanOrEqual(viewModel.loadedPageImages.count, 3,
                                 "the editor is holding \(viewModel.loadedPageImages.count) page images")
    }

    /// Turning pages moves the window: what is behind you is dropped, so a walk
    /// through a long document costs the same as sitting on page one.
    @MainActor
    func testTurningPagesDropsTheOnesLeftBehind() {
        let viewModel = self.makeViewModel(pdf: Pdf(pdfDocument: self.makeTextDocument(pageCount: 40)))
        XCTAssertTrue(self.wait(upTo: 20) { !viewModel.isPreparingPages })
        XCTAssertTrue(self.wait(upTo: 10) { viewModel.pageImage(at: 0) != nil })

        for index in 1..<40 {
            viewModel.pdfCurrentPageIndex = index
            _ = self.wait(upTo: 5) { viewModel.pageImage(at: index) != nil }
        }

        XCTAssertNotNil(viewModel.pageImage(at: 39), "the page on screen is not drawn")
        XCTAssertNil(viewModel.pageImage(at: 0), "the first page is still being held")
        XCTAssertLessThanOrEqual(viewModel.loadedPageImages.count, 3,
                                 "the editor is holding \(viewModel.loadedPageImages.count) page images")
    }

    /// The pages either side are drawn too, so a swipe does not wait for a render.
    @MainActor
    func testTheNeighbouringPagesAreDrawnAhead() {
        let viewModel = self.makeViewModel(pdf: Pdf(pdfDocument: self.makeTextDocument(pageCount: 10)))
        XCTAssertTrue(self.wait(upTo: 20) { !viewModel.isPreparingPages })

        viewModel.pdfCurrentPageIndex = 5
        XCTAssertTrue(self.wait(upTo: 10) { viewModel.pageImage(at: 6) != nil },
                      "the next page was not drawn ahead of being reached")
        XCTAssertNotNil(viewModel.pageImage(at: 4))
        XCTAssertNil(viewModel.pageImage(at: 7))
    }

    /// A page keeps its drawn image when it moves: the images are keyed by the
    /// page's own identity, not by where it happens to sit.
    @MainActor
    func testAPageKeepsItsImageWhenItMoves() {
        let viewModel = self.makeViewModel(pdf: Pdf(pdfDocument: self.makeTextDocument(pageCount: 4)))
        XCTAssertTrue(self.wait(upTo: 20) { !viewModel.isPreparingPages })
        XCTAssertTrue(self.wait(upTo: 10) { viewModel.pageImage(at: 0) != nil })
        let firstPageImage = viewModel.pageImage(at: 0)

        viewModel.movePages(from: IndexSet(integer: 0), to: 2)

        XCTAssertEqual(viewModel.pageImage(at: 1), firstPageImage,
                       "the page was drawn again just for having moved")
    }

    // MARK: - Fixtures

    @MainActor
    private func makeViewModel(pdf: Pdf) -> PdfEditViewModel {
        PdfEditViewModel(inputParameter: .init(pdf: pdf,
                                               startAction: nil,
                                               shouldShowCloseWarning: .constant(false)))
    }

    /// Spins the main runloop, which is what lets the pages drawn in the
    /// background be published back.
    private func wait(upTo seconds: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    /// Pages that are one big photograph, the way a scan is.
    private func makeScan(pageCount: Int) -> PDFDocument {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 3024, height: 4032)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3024, height: 4032))
            for row in 0..<40 {
                UIColor(white: 0.2, alpha: 1).setFill()
                context.fill(CGRect(x: 200, y: 200 + row * 90, width: 2600, height: 40))
            }
        }
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for _ in 0..<pageCount {
                context.beginPage()
                photo.draw(in: bounds)
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    private func makeTextDocument(pageCount: Int) -> PDFDocument {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for index in 0..<pageCount {
                context.beginPage()
                ("Page \(index)" as NSString).draw(at: CGPoint(x: 40, y: 40),
                                                   withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }
}

// MARK: - Mocks

private final class OpeningAnalyticsMock: AnalyticsManager {
    func track(event: AnalyticsEvent) {}
}

private final class OpeningRepositoryMock: Repository {
    func savePdf(pdf: Pdf) throws -> Pdf { pdf }
    func getDoPdfExist() throws -> Bool { false }
    func loadPdfs() throws -> [Pdf] { [] }
    func delete(pdf: Pdf) throws {}
    func saveSignature(signature: Signature) throws -> Signature { signature }
    func getDoSignatureExist() throws -> Bool { false }
    func loadSignatures() throws -> [Signature] { [] }
    func delete(signature: Signature) throws {}
    func delete(signatures: [Signature]) throws {}
    func saveSuggestedFields(suggestedFields: SuggestedFields) throws -> SuggestedFields { suggestedFields }
    func loadSuggestedFields() throws -> SuggestedFields? { nil }
    func loadFolders() throws -> [Folder] { [] }
    func save(folder: Folder) throws -> Folder { folder }
    func delete(folder: Folder) throws {}
    func setFolder(_ folder: Folder?, for pdf: Pdf) throws -> Pdf { pdf }
    func loadTags() throws -> [Tag] { [] }
    func save(tag: Tag) throws -> Tag { tag }
    func delete(tag: Tag) throws {}
    func setTags(_ tags: [Tag], for pdf: Pdf) throws -> Pdf { pdf }
}
