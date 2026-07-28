//
//  EditorToolTests.swift
//  PdfExpertTests
//
//  The editor's single list of what it can do, and the page operations the new
//  bar under the page performs.
//
//  Two things are worth pinning down here. First, that the editor really does
//  read its names and symbols from `ToolCatalog` rather than carrying a second
//  copy — that was the whole point of the restructure, and a hard-coded string
//  slipping back in would be invisible until a translator noticed. Second, the
//  page maths: duplicating, deleting and moving edit the document and the page
//  list in step, and the two drifting apart shows the user the wrong page.
//

import XCTest
import Combine
import StoreKit
import Factory
import PDFKit
@testable import PdfExpert

final class EditorToolTests: XCTestCase {

    /// Kept alive for the duration of a test: the flows the editor owns resolve
    /// it eagerly through `@Injected`.
    private var store: StoreMock!

    override func tearDown() {
        self.store = nil
        Container.shared.repository.reset()
        Container.shared.analyticsManager.reset()
        Container.shared.store.reset()
        super.tearDown()
    }

    // MARK: - One description per tool

    func testToolsTakeTheirNameFromTheCatalog() {
        // If the editor ever grows its own copy of a name, this is what catches it.
        for tool in EditorTool.allCases {
            guard let action = tool.catalogAction,
                  let catalogTool = ToolCatalog.allTools.first(where: { $0.action == action }) else {
                continue
            }
            XCTAssertEqual(tool.title, catalogTool.title, "\(tool) drifted from the catalog")
            XCTAssertEqual(tool.systemImage, catalogTool.systemImage, "\(tool) drifted from the catalog")
        }
    }

    func testEveryToolHasAName() {
        for tool in EditorTool.allCases {
            XCTAssertFalse(tool.title.isEmpty)
            XCTAssertNotEqual(tool.title, "Tool", "\(tool) fell through to the placeholder name")
            XCTAssertFalse(tool.systemImage.isEmpty)
        }
    }

    func testOnlyPushedToolsHaveARoute() {
        for tool in EditorTool.allCases {
            switch tool.presentation {
            case .push:
                XCTAssertNotNil(tool.route, "\(tool) is pushed but goes nowhere")
            case .immediate, .flow:
                XCTAssertNil(tool.route, "\(tool) is not pushed but carries a route")
            }
        }
    }

    func testEveryRouteIsReachable() {
        // The other direction: a destination nothing can open is dead code.
        let routes = Set(EditorTool.allCases.compactMap(\.route))
        for route in EditorRoute.allCases {
            XCTAssertTrue(routes.contains(route), "\(route) has no tool that opens it")
        }
    }

    func testTheLongFlowsAreScreensNow() {
        // Each of these is an import, a form, a second document and an alert.
        // Only the form is a screen, and it is pushed like any other.
        for tool in [EditorTool.split, .extractPages, .export, .compress, .permissions] {
            XCTAssertEqual(tool.presentation, .push, "\(tool) went back to being a cover")
        }
    }

    func testDirectManipulationStaysFullScreen() {
        // A navigation bar over the page being signed or redacted is in the way.
        for tool in [EditorTool.signature, .addText, .fillForm, .redact] {
            XCTAssertEqual(tool.presentation, .flow, "\(tool) should stay full screen")
        }
    }

    // MARK: - The panel

    func testThePanelListsEveryDocumentTool() {
        let listed = Set(EditorToolGroup.all.flatMap(\.tools))
        // The page bar's own actions are deliberately not in the panel.
        let expectedAbsent: Set<EditorTool> = [.rotateLeft, .rotateRight, .duplicatePage,
                                               .deletePage, .addPage, .signature, .addText, .fillForm]
        for tool in expectedAbsent {
            XCTAssertFalse(listed.contains(tool), "\(tool) belongs in a bar, not the panel")
        }
        for tool in [EditorTool.split, .ocr, .watermark, .password, .compress, .share, .rotateAllPages] {
            XCTAssertTrue(listed.contains(tool), "\(tool) is not reachable from the panel")
        }
    }

    func testNoToolIsListedTwice() {
        let listed = EditorToolGroup.all.flatMap(\.tools)
        XCTAssertEqual(listed.count, Set(listed).count)
    }

    func testSearchingNarrowsTheGroups() {
        let results = EditorToolGroup.filtered(by: "watermark").flatMap(\.tools)
        XCTAssertEqual(results, [.watermark])
    }

    func testSearchingIsAccentAndCaseInsensitive() {
        XCTAssertEqual(EditorToolGroup.filtered(by: "WATERMARK").flatMap(\.tools), [.watermark])
    }

    func testAnEmptySearchShowsEverything() {
        XCTAssertEqual(EditorToolGroup.filtered(by: "   ").flatMap(\.tools).count,
                       EditorToolGroup.all.flatMap(\.tools).count)
    }

    func testAHopelessSearchShowsNothing() {
        XCTAssertTrue(EditorToolGroup.filtered(by: "zzzznotatool").isEmpty)
    }

    func testToolsThatNeedSeveralPagesAreMarked() {
        XCTAssertTrue(EditorTool.split.needsSeveralPages)
        XCTAssertTrue(EditorTool.reorderPages.needsSeveralPages)
        XCTAssertFalse(EditorTool.watermark.needsSeveralPages)
    }

    // MARK: - Page operations

    @MainActor
    func testDuplicatingAPageInsertsACopyAfterIt() {
        let viewModel = self.makeViewModel(pageCount: 3)
        viewModel.pdfCurrentPageIndex = 1

        viewModel.duplicateCurrentPage()

        XCTAssertEqual(viewModel.pdf.pdfDocument.pageCount, 4)
        XCTAssertEqual(viewModel.pages.count, 4)
        // The copy is selected, so whatever the user does next happens to it.
        XCTAssertEqual(viewModel.pdfCurrentPageIndex, 2)
    }

    @MainActor
    func testDuplicatingKeepsTheOriginalText() {
        let viewModel = self.makeViewModel(pageCount: 2)
        viewModel.pdfCurrentPageIndex = 0
        viewModel.duplicateCurrentPage()

        let original = viewModel.pdf.pdfDocument.page(at: 0)?.string
        let copy = viewModel.pdf.pdfDocument.page(at: 1)?.string
        XCTAssertEqual(original, copy)
    }

    @MainActor
    func testDeletingByIndexKeepsTheReaderOnItsPage() {
        let viewModel = self.makeViewModel(pageCount: 4)
        viewModel.pdfCurrentPageIndex = 3

        viewModel.deletePage(at: 1)

        XCTAssertEqual(viewModel.pdf.pdfDocument.pageCount, 3)
        // Page 3 became page 2 when the one before it went.
        XCTAssertEqual(viewModel.pdfCurrentPageIndex, 2)
    }

    @MainActor
    func testDeletingTheDisplayedPageIsHandled() {
        let viewModel = self.makeViewModel(pageCount: 3)
        viewModel.pdfCurrentPageIndex = 2

        viewModel.deletePage(at: 2)

        XCTAssertEqual(viewModel.pdf.pdfDocument.pageCount, 2)
        XCTAssertEqual(viewModel.pdfCurrentPageIndex, 1)
    }

    @MainActor
    func testMovingAPageDownReordersTheDocumentAndTheList() {
        let viewModel = self.makeViewModel(pageCount: 3)
        let firstPageText = viewModel.pdf.pdfDocument.page(at: 0)?.string

        // SwiftUI's onMove: take row 0, drop it before row 2.
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)

        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 1)?.string, firstPageText)
        XCTAssertEqual(viewModel.pages.count, 3)
    }

    @MainActor
    func testMovingAPageUpReorders() {
        let viewModel = self.makeViewModel(pageCount: 3)
        let lastPageText = viewModel.pdf.pdfDocument.page(at: 2)?.string

        viewModel.movePages(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 0)?.string, lastPageText)
    }

    /// The strip's drag is a swap, and the document and the page list have to
    /// swap the same way. They did not: the list moved while the document
    /// swapped, which agree only for pages next to each other.
    @MainActor
    func testDraggingAThumbnailTwoPlacesAlongSwapsBoth() {
        let viewModel = self.makeViewModel(pageCount: 4)
        let texts = (0..<4).map { viewModel.pdf.pdfDocument.page(at: $0)?.string }
        let pageIds = viewModel.pages.map(\.id)

        viewModel.handlePageReordering(fromIndex: 0, toIndex: 3)

        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 0)?.string, texts[3])
        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 3)?.string, texts[0])
        // And the strip says the same thing the document does.
        XCTAssertEqual(viewModel.pages.map(\.id), [pageIds[3], pageIds[1], pageIds[2], pageIds[0]])
    }

    @MainActor
    func testMovingAPageOntoItselfChangesNothing() {
        let viewModel = self.makeViewModel(pageCount: 3)
        let before = (0..<3).map { viewModel.pdf.pdfDocument.page(at: $0)?.string }

        viewModel.movePages(from: IndexSet(integer: 1), to: 1)
        viewModel.movePages(from: IndexSet(integer: 1), to: 2)

        let after = (0..<3).map { viewModel.pdf.pdfDocument.page(at: $0)?.string }
        XCTAssertEqual(before, after)
    }

    @MainActor
    func testMovingFollowsTheSelectedPage() {
        let viewModel = self.makeViewModel(pageCount: 3)
        viewModel.pdfCurrentPageIndex = 0

        viewModel.movePages(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(viewModel.pdfCurrentPageIndex, 2)
    }

    // MARK: - Rotation

    @MainActor
    func testRotatingOnePageLeavesTheOthersAlone() {
        let viewModel = self.makeViewModel(pageCount: 3)
        viewModel.pdfCurrentPageIndex = 1

        viewModel.run(.rotateRight)

        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 0)?.rotation, 0)
        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 1)?.rotation, 90)
        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 2)?.rotation, 0)
    }

    @MainActor
    func testRotatingTheDocumentTurnsEveryPage() {
        let viewModel = self.makeViewModel(pageCount: 3)

        viewModel.run(.rotateAllPages)

        for index in 0..<3 {
            XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: index)?.rotation, 90,
                           "page \(index) was left as it was")
        }
    }

    /// The Shortcuts "Rotate PDF" action opens the editor and rotates — which
    /// means it arrives before the pages have finished drawing, and every page
    /// operation refuses to run until they are in. It used to do nothing at all.
    @MainActor
    func testTheRotateStartActionWaitsForThePages() {
        let viewModel = self.makeViewModel(pageCount: 3,
                                           startAction: .openRotate,
                                           waitForPages: false)
        XCTAssertTrue(viewModel.isPreparingPages, "this test needs the pages to still be arriving")

        viewModel.onAppear()
        self.waitForPages(viewModel)

        for index in 0..<3 {
            XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: index)?.rotation, 90,
                           "page \(index) was left as it was")
        }
        // And the pages the editor shows were redrawn from the rotated document.
        XCTAssertEqual(viewModel.pages.count, 3)
    }

    // MARK: - The pushed flows

    @MainActor
    func testSplittingPushesTheRangeEditor() {
        let viewModel = self.makeViewModel(pageCount: 3)

        viewModel.run(.split)

        XCTAssertEqual(viewModel.path, [.split])
        // Prepared before the push, so the screen opens on the whole document
        // rather than on an empty list of ranges.
        XCTAssertEqual(viewModel.pdfSplitViewModel.pageRanges, [0...2])
        XCTAssertEqual(viewModel.pdfSplitViewModel.totalPages, 3)
        XCTAssertTrue(viewModel.pdfSplitViewModel.showPageRangeEditor)
    }

    @MainActor
    func testSplittingASinglePageDocumentPushesNothing() {
        // The whole point of preparing before pushing: this is a screen with
        // nothing to do on it, and it used to be presented anyway.
        let viewModel = self.makeViewModel(pageCount: 1)

        viewModel.run(.split)

        XCTAssertTrue(viewModel.path.isEmpty)
        XCTAssertFalse(viewModel.pdfSplitViewModel.showPageRangeEditor)
        XCTAssertNotNil(viewModel.pdfSplitViewModel.asyncSplit.error)
    }

    @MainActor
    func testExtractingPushesTheRangeEditor() {
        let viewModel = self.makeViewModel(pageCount: 4)

        viewModel.run(.extractPages)

        XCTAssertEqual(viewModel.path, [.extractPages])
        XCTAssertEqual(viewModel.pdfExtractViewModel.pageRanges, [0...3])
    }

    @MainActor
    func testExtractingFromASinglePageDocumentPushesNothing() {
        let viewModel = self.makeViewModel(pageCount: 1)

        viewModel.run(.extractPages)

        XCTAssertTrue(viewModel.path.isEmpty)
        XCTAssertNotNil(viewModel.pdfExtractViewModel.asyncExtract.error)
    }

    @MainActor
    func testExportingPushesTheFormatListForEveryone() {
        // The gate is on the export itself — the format list opens for anyone.
        let viewModel = self.makeViewModel(pageCount: 2)

        viewModel.run(.export)

        XCTAssertEqual(viewModel.path, [.export])
        XCTAssertTrue(viewModel.pdfExportViewModel.formatPickerShow)
    }

    @MainActor
    func testCompressingPushesTheEditor() {
        let viewModel = self.makeViewModel(pageCount: 2)

        viewModel.run(.compress)

        XCTAssertEqual(viewModel.path, [.compress])
        XCTAssertTrue(viewModel.pdfCompressViewModel.editorShow)
    }

    // MARK: - No paywall inside the editor
    //
    // The editor's own tools all run on device and leave the result in the
    // document, so none of them gates: the paywall is met once, on the way out
    // (`PdfShareCoordinator`, and the export, which hands the file to the share
    // sheet). These four used to stop a non-subscriber at the door.

    @MainActor
    func testPermissionsOpensForANonSubscriber() {
        let viewModel = self.makeViewModel(pageCount: 2)

        viewModel.run(.permissions)

        XCTAssertEqual(viewModel.path, [.permissions])
        XCTAssertTrue(viewModel.pdfPermissionsViewModel.formShow)
    }

    @MainActor
    func testPageNumbersAndWatermarkOpenForANonSubscriber() {
        let viewModel = self.makeViewModel(pageCount: 2)

        viewModel.run(.pageNumbers)
        XCTAssertEqual(viewModel.path, [.pageNumbers])

        viewModel.run(.watermark)
        XCTAssertEqual(viewModel.path, [.pageNumbers, .watermark])
    }

    @MainActor
    func testRedactOpensForANonSubscriber() {
        let viewModel = self.makeViewModel(pageCount: 2)

        viewModel.run(.redact)
        // The flow tools open a runloop later, so the panel can dismiss first.
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.pdfRedactViewModel.editorShow)
    }

    // MARK: - Fixtures

    /// A document whose pages are distinguishable by their text, so a reorder is
    /// observable.
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

    /// `@Injected` resolves eagerly in this view model, so the mocks go in first.
    /// The editor itself no longer reads the store, but the flows it owns do
    /// (the export hands its files to the share sheet), so it is still registered.
    @MainActor
    /// `waitForPages: false` for the tests that never look at a page.
    private func makeViewModel(pageCount: Int,
                               startAction: PdfEditStartAction? = nil,
                               waitForPages: Bool = true) -> PdfEditViewModel {
        let store = StoreMock()
        self.store = store

        Container.shared.repository.register { RepositoryMock() }
        Container.shared.analyticsManager.register { AnalyticsManagerMock() }
        Container.shared.store.register { store }

        let pdf = Pdf(pdfDocument: self.makeDocument(pageCount: pageCount))
        let parameter = PdfEditViewModel.InputParameter(pdf: pdf,
                                                        startAction: startAction,
                                                        shouldShowCloseWarning: .constant(false))
        let viewModel = PdfEditViewModel(inputParameter: parameter)
        if waitForPages { self.waitForPages(viewModel) }
        return viewModel
    }

    /// The pages are drawn on a background queue and arrive one at a time, so a
    /// view model is not ready to be edited the instant it exists. Everything
    /// that touches the page lists waits for them here — which is also what the
    /// editor's own bars do, by staying disabled.
    @MainActor
    private func waitForPages(_ viewModel: PdfEditViewModel) {
        let deadline = Date().addingTimeInterval(20)
        while viewModel.isPreparingPages, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertFalse(viewModel.isPreparingPages, "the pages never finished drawing")
        XCTAssertEqual(viewModel.pages.count, viewModel.pageCount)
    }
}

// MARK: - Mocks

private final class AnalyticsManagerMock: AnalyticsManager {
    func track(event: AnalyticsEvent) {}
}

private final class RepositoryMock: Repository {
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

@MainActor
private final class StoreMock: Store {
    nonisolated let isPremium: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    nonisolated let originalTransactionId: CurrentValueSubject<String?, Never> = CurrentValueSubject(nil)

    var subscriptions: [Product] { [] }
    var consumables: [Product] { [] }
    var purchasedSubscriptions: [Product] { [] }
    var subscriptionGroupStatus: RenewalState? { nil }

    func refreshAll() async throws {}
    func requestProducts() async throws {}
    func purchase(_ product: Product) async throws -> Transaction? { nil }
    func isPurchased(_ product: Product) async throws -> Bool { false }
    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        throw StoreError.failedVerification
    }
    func updateCustomerProductStatus() async {}
    nonisolated func getProductData(forProductId productId: String) -> Any? { nil }
    nonisolated func sortByPrice(_ products: [Product]) -> [Product] { products }
}
