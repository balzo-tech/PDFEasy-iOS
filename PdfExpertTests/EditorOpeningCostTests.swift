//
//  EditorOpeningCostTests.swift
//  PdfExpertTests
//
//  What it costs to open a document in the editor.
//
//  Opening builds two images per page — one for the pager, one for the strip —
//  and it used to build all of them synchronously inside `init`, and again after
//  every tool. On a text document that is free. On a scan it is not: the cost is
//  decoding the photograph inside each page, it is paid twice per page whatever
//  size comes out, and it measured **0.9s per page on a Mac**. A twenty-page
//  scan therefore froze the editor for eighteen seconds before it drew anything
//  — which from the outside is indistinguishable from an editor whose buttons do
//  not work, because for those eighteen seconds they do not.
//
//  These tests hold the line: opening returns immediately, and the pages arrive
//  afterwards.
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
        let firstPageArrived = self.wait(upTo: 20) { viewModel.pageImages.count >= 1 }

        XCTAssertTrue(firstPageArrived, "no page was drawn")
        XCTAssertEqual(viewModel.pdfThumbnails.count, viewModel.pageImages.count,
                       "the pager and the strip drifted apart")
        // Until every page is in, nothing is allowed to reorder or delete them.
        XCTAssertEqual(viewModel.canEditPages, !viewModel.isPreparingPages)
    }

    @MainActor
    func testAShortDocumentIsReadyAlmostImmediately() {
        let viewModel = self.makeViewModel(pdf: Pdf(pdfDocument: self.makeTextDocument(pageCount: 3)))

        XCTAssertTrue(self.wait(upTo: 10) { !viewModel.isPreparingPages })
        XCTAssertEqual(viewModel.pageImages.count, 3)
        XCTAssertTrue(viewModel.canEditPages)
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
