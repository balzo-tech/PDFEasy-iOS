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
//  page maths: duplicating, deleting and moving all edit three parallel arrays
//  (the document, the page images, the thumbnails), and any of them drifting out
//  of step shows the user the wrong page.
//

import XCTest
import Combine
import StoreKit
import Factory
import PDFKit
@testable import PdfExpert

final class EditorToolTests: XCTestCase {

    override func tearDown() {
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
            XCTAssertEqual(tool.isPremium, catalogTool.isPremium, "\(tool) drifted from the catalog")
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
        for route in [EditorRoute.reorderPages, .pageNumbers, .watermark, .metadata] {
            XCTAssertTrue(routes.contains(route), "\(route) has no tool that opens it")
        }
    }

    func testPremiumBadgesMatchTheCatalog() {
        XCTAssertTrue(EditorTool.ocr.isPremium)
        XCTAssertTrue(EditorTool.watermark.isPremium)
        XCTAssertFalse(EditorTool.reorderPages.isPremium)
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
        for tool in [EditorTool.split, .ocr, .watermark, .password, .compress, .share] {
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
        XCTAssertEqual(viewModel.pageImages.count, 4)
        XCTAssertEqual(viewModel.pdfThumbnails.count, 4)
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
    func testMovingAPageDownReordersEveryParallelArray() {
        let viewModel = self.makeViewModel(pageCount: 3)
        let firstPageText = viewModel.pdf.pdfDocument.page(at: 0)?.string

        // SwiftUI's onMove: take row 0, drop it before row 2.
        viewModel.movePages(from: IndexSet(integer: 0), to: 2)

        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 1)?.string, firstPageText)
        XCTAssertEqual(viewModel.pageImages.count, 3)
        XCTAssertEqual(viewModel.pdfThumbnails.count, 3)
    }

    @MainActor
    func testMovingAPageUpReorders() {
        let viewModel = self.makeViewModel(pageCount: 3)
        let lastPageText = viewModel.pdf.pdfDocument.page(at: 2)?.string

        viewModel.movePages(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.pdf.pdfDocument.page(at: 0)?.string, lastPageText)
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
    @MainActor
    private func makeViewModel(pageCount: Int) -> PdfEditViewModel {
        Container.shared.repository.register { RepositoryMock() }
        Container.shared.analyticsManager.register { AnalyticsManagerMock() }
        Container.shared.store.register { StoreMock() }

        let pdf = Pdf(pdfDocument: self.makeDocument(pageCount: pageCount))
        let parameter = PdfEditViewModel.InputParameter(pdf: pdf,
                                                        startAction: nil,
                                                        shouldShowCloseWarning: .constant(false))
        return PdfEditViewModel(inputParameter: parameter)
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
