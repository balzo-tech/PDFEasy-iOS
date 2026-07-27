//
//  PdfAppendAndShareTests.swift
//  PdfExpertTests
//
//  The three areas the backlog has been asking for since the old NEXT_TASKS.md:
//  the paths that append pages to an open document, the progress a scan reports
//  while it is being turned into a PDF, and what actually comes out of the share
//  sheet.
//
//  They have one thing in common: each is a place where the document the user
//  ends up with can quietly differ from the one they were looking at. A page
//  appended while the editor is still drawing gets counted twice; a scan that
//  reports no progress looks frozen; a shared file that is re-processed on its
//  way out is not the file that was saved — which is exactly what phase 9 set
//  out to fix.
//

import XCTest
import PDFKit
import Combine
import SwiftUI
import StoreKit
import Factory
@testable import PdfExpert

final class PdfAppendAndShareTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Container.shared.repository.register { AppendRepositoryMock() }
        Container.shared.analyticsManager.register { AppendAnalyticsMock() }
    }

    override func tearDown() {
        Container.shared.repository.reset()
        Container.shared.analyticsManager.reset()
        super.tearDown()
    }

    // MARK: - Appending to a document

    func testAppendingAnImageAddsOnePage() {
        let document = self.makeDocument(pageCount: 2)

        PDFUtility.appendImageToPdfDocument(pdfDocument: document, uiImage: self.makeImage())

        XCTAssertEqual(document.pageCount, 3)
    }

    func testAppendingADocumentAddsAllOfItsPages() {
        let document = self.makeDocument(pageCount: 2)
        let addition = self.makeDocument(pageCount: 3)

        PDFUtility.appendPdfDocument(addition, toPdfDocument: document)

        XCTAssertEqual(document.pageCount, 5)
        // In order, after the ones that were already there.
        XCTAssertTrue(document.page(at: 2)?.string?.contains("Page number 0") ?? false)
    }

    @MainActor
    func testAppendingAPdfInTheEditorKeepsTheStripInStep() {
        let viewModel = self.makeEditor(pageCount: 2)
        // What the file picker sets on its way in; the append asserts on it.
        viewModel.currentAnalyticsPdfInputType = .file

        viewModel.asyncPdf = AsyncOperation(status: .data(Pdf(pdfDocument: self.makeDocument(pageCount: 3))))

        XCTAssertEqual(viewModel.pdf.pdfDocument.pageCount, 5)
        XCTAssertEqual(viewModel.pages.count, 5, "the page list drifted from the document")
    }

    @MainActor
    func testAppendingAnImageInTheEditorKeepsTheStripInStep() {
        let viewModel = self.makeEditor(pageCount: 2)
        viewModel.currentAnalyticsPdfInputType = .gallery

        viewModel.imageToConvert = self.makeImage()
        viewModel.convert()

        XCTAssertEqual(viewModel.pdf.pdfDocument.pageCount, 3)
        XCTAssertEqual(viewModel.pages.count, 3)
    }

    /// The case the code comments warn about: a page that arrives while the
    /// editor is still drawing would be appended twice — once by the append, once
    /// by the render still walking the document. The render is abandoned instead.
    @MainActor
    func testAPageAddedWhileTheEditorIsStillDrawingIsNotCountedTwice() {
        let viewModel = self.makeEditor(pageCount: 3, waitForPages: false)
        viewModel.currentAnalyticsPdfInputType = .file
        XCTAssertTrue(viewModel.isPreparingPages, "this test needs the pages to still be arriving")

        viewModel.asyncPdf = AsyncOperation(status: .data(Pdf(pdfDocument: self.makeDocument(pageCount: 2))))

        XCTAssertEqual(viewModel.pdf.pdfDocument.pageCount, 5)
        self.waitForPages(viewModel)
        XCTAssertEqual(viewModel.pages.count, 5, "the appended pages were drawn twice")
    }

    // MARK: - What a scan reports while it is being built

    func testTheScanReportsProgressOncePerPage() {
        let pages = (0..<4).map { _ in ScannedPage(original: self.makeImage(), filter: .original) }
        var reported: [Int] = []

        let document = PdfScanUtility.makeDocument(from: pages) { reported.append($0) }

        XCTAssertEqual(document.pageCount, 4)
        // One report per page, in order, ending on the total — which is what the
        // progress bar is driven from.
        XCTAssertEqual(reported, [1, 2, 3, 4])
    }

    func testTheScanReportsProgressEvenForAPageThatWillNotRender() {
        // A page that fails to render must still tick the counter, or the bar
        // stops short of the end and the flow looks stuck.
        let pages = [ScannedPage(original: UIImage(), filter: .original),
                     ScannedPage(original: self.makeImage(), filter: .original)]
        var reported: [Int] = []

        _ = PdfScanUtility.makeDocument(from: pages) { reported.append($0) }

        XCTAssertEqual(reported, [1, 2])
    }

    @MainActor
    func testConvertingAScanEndsWithTheDocumentAndAFullProgressBar() {
        let pages = (0..<3).map { _ in ScannedPage(original: self.makeImage(), filter: .original) }
        var operation: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty)
        let binding = Binding(get: { operation }, set: { operation = $0 })

        PdfScanUtility.convertScan(pages: pages, asyncOperation: binding)

        // A determinate bar from the first frame, not a spinner: the count of
        // pages is known before any of them has been rendered.
        guard case .loading(let progress) = operation.status else {
            return XCTFail("the flow did not start in a loading state")
        }
        XCTAssertEqual(progress.totalUnitCount, 3)

        XCTAssertTrue(self.wait(upTo: 20) { operation.data != nil }, "the scan never finished")
        XCTAssertEqual(operation.data?.pdfDocument.pageCount, 3)
    }

    @MainActor
    func testAScanOfNothingReportsAnErrorRatherThanAnEmptyDocument() {
        var operation: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty)
        let binding = Binding(get: { operation }, set: { operation = $0 })

        PdfScanUtility.convertScan(pages: [], asyncOperation: binding)

        XCTAssertTrue(self.wait(upTo: 10) { operation.error != nil })
        XCTAssertNil(operation.data)
    }

    // MARK: - What comes out of the share sheet

    func testTheSharedFileIsTheDocumentAsItWasSaved() throws {
        let pdf = Pdf(pdfDocument: self.makeDocument(pageCount: 3))
        defer { PDFUtility.cleanSharedPdf(pdf: pdf) }

        let url = PDFUtility.processToShare(pdf: pdf)

        let shared = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertEqual(shared.pageCount, 3)
        // Same text, page for page: nothing is re-rendered or re-compressed on
        // the way out, which is the promise phase 9 made.
        for index in 0..<3 {
            XCTAssertEqual(shared.page(at: index)?.string, pdf.pdfDocument.page(at: index)?.string)
        }
    }

    func testASharedFileCarriesThePasswordWithIt() throws {
        var pdf = Pdf(pdfDocument: self.makeDocument(pageCount: 1))
        pdf.updatePassword("hunter2")
        defer { PDFUtility.cleanSharedPdf(pdf: pdf) }

        let url = PDFUtility.processToShare(pdf: pdf)

        let shared = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertTrue(shared.isLocked, "the shared file went out unprotected")
        XCTAssertTrue(shared.unlock(withPassword: "hunter2"))
    }

    func testTheTemporaryFileIsCleanedUpAfterSharing() {
        let pdf = Pdf(pdfDocument: self.makeDocument(pageCount: 1))
        let url = PDFUtility.processToShare(pdf: pdf)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        PDFUtility.cleanSharedPdf(pdf: pdf)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "the document is left sitting in the temporary directory")
    }

    // MARK: - Fixtures

    private func makeDocument(pageCount: Int) -> PDFDocument {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for index in 0..<pageCount {
                context.beginPage()
                ("Page number \(index)" as NSString)
                    .draw(at: CGPoint(x: 40, y: 40),
                          withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 40, y: 40, width: 220, height: 20))
        }
    }

    @MainActor
    private func makeEditor(pageCount: Int, waitForPages: Bool = true) -> PdfEditViewModel {
        let parameter = PdfEditViewModel.InputParameter(pdf: Pdf(pdfDocument: self.makeDocument(pageCount: pageCount)),
                                                        startAction: nil,
                                                        shouldShowCloseWarning: .constant(false))
        let viewModel = PdfEditViewModel(inputParameter: parameter)
        if waitForPages { self.waitForPages(viewModel) }
        return viewModel
    }

    /// The pages are drawn on a background queue, so a view model is not ready to
    /// be inspected the instant it exists.
    @MainActor
    private func waitForPages(_ viewModel: PdfEditViewModel) {
        XCTAssertTrue(self.wait(upTo: 20) { !viewModel.isPreparingPages },
                      "the pages never finished drawing")
    }

    private func wait(upTo seconds: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }
}

// MARK: - Mocks

private final class AppendAnalyticsMock: AnalyticsManager {
    func track(event: AnalyticsEvent) {}
}

private final class AppendRepositoryMock: Repository {
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
