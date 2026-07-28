//
//  PdfAdvancedToolViewModelTests.swift
//  PdfExpertTests
//
//  Unit tests for the PDF-in / PDF-out Stirling tools (Convert to PDF/A, Repair,
//  Sanitize). The pure parts (tool → operation / suffix mapping, display metadata)
//  are tested directly. The stateful flow (one-time privacy disclosure, premium
//  gate, network processing → archive save) is driven through a fully-instantiated
//  view model whose dependencies are replaced with lightweight mocks registered on
//  the Factory container. The Stirling mock returns synchronously (no stub delay) so
//  the success path can be exercised without waiting.
//

import XCTest
import Combine
import StoreKit
import Factory
import PDFKit
@testable import PdfExpert

final class PdfAdvancedToolViewModelTests: XCTestCase {

    override func tearDown() {
        // Restore the real dependencies so other test cases are unaffected.
        Container.shared.store.reset()
        Container.shared.cacheManager.reset()
        Container.shared.analyticsManager.reset()
        Container.shared.stirlingApiManager.reset()
        Container.shared.repository.reset()
        super.tearDown()
    }

    // MARK: - Fixtures

    /// Raw bytes of a real single-page PDF (so `Pdf(data:)` succeeds).
    private func makePdfData() -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            ("Process me" as NSString).draw(at: CGPoint(x: 50, y: 50),
                                            withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
    }

    /// A single-page PDF with real content (non-nil `rawData`, `pageCount == 1`).
    private func makeSinglePagePdf() -> Pdf {
        Pdf(pdfDocument: PDFDocument(data: self.makePdfData()) ?? PDFDocument())
    }

    /// Registers the mocked dependencies and returns a fresh view model. `@Injected`
    /// resolves eagerly at init, so the mocks must be registered first.
    @MainActor
    private func makeViewModel(premium: Bool,
                              disclosureAccepted: Bool,
                              cache: CacheManagerMock,
                              repository: RepositoryMock = RepositoryMock(),
                              stirling: StirlingMock = StirlingMock()) -> PdfAdvancedToolViewModel {
        let store = StoreMock()
        store.isPremium.value = premium
        cache.pdfConvertPrivacyAccepted = disclosureAccepted
        Container.shared.store.register { store }
        Container.shared.cacheManager.register { cache }
        Container.shared.analyticsManager.register { AnalyticsManagerMock() }
        Container.shared.stirlingApiManager.register { stirling }
        Container.shared.repository.register { repository }
        return PdfAdvancedToolViewModel()
    }

    /// Spins the main run loop once so deferred (`DispatchQueue.main.async`) work runs.
    private func pumpMainQueue() {
        let exp = expectation(description: "pump main queue")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - Pure: tool → operation / suffix / metadata

    func testToolMapsToStirlingOperation() {
        XCTAssertEqual(PdfAdvancedTool.pdfa.operation, .pdfToPdfa)
        XCTAssertEqual(PdfAdvancedTool.repair.operation, .repair)
        XCTAssertEqual(PdfAdvancedTool.sanitize.operation, .sanitize)
    }

    func testEveryToolProducesAPdf() {
        for tool in PdfAdvancedTool.allCases {
            XCTAssertEqual(StirlingApiManagerImpl.defaultExtension(for: tool.operation), "pdf")
        }
    }

    func testToolFilenameSuffixes() {
        XCTAssertEqual(PdfAdvancedTool.pdfa.filenameSuffix, "-pdfa")
        XCTAssertEqual(PdfAdvancedTool.repair.filenameSuffix, "-repaired")
        XCTAssertEqual(PdfAdvancedTool.sanitize.filenameSuffix, "-sanitized")
    }

    func testEveryToolHasDisplayMetadata() {
        for tool in PdfAdvancedTool.allCases {
            XCTAssertFalse(tool.displayName.isEmpty)
            XCTAssertFalse(tool.systemImageName.isEmpty)
            XCTAssertFalse(tool.successMessage.isEmpty)
        }
    }

    // MARK: - Privacy disclosure (one-time, shared with the convert flow)

    @MainActor
    func testFirstRunRequiresDisclosureAndPersistsOnAccept() {
        let cache = CacheManagerMock()
        // First ever online run: disclosure not yet accepted. Non-premium so the flow
        // stops at the paywall after acceptance (never hitting the network), keeping
        // the assertions deterministic and focused on the disclosure behaviour.
        let vm = self.makeViewModel(premium: false, disclosureAccepted: false, cache: cache)

        vm.run(pdf: self.makeSinglePagePdf(), tool: .pdfa, onCompleted: nil)
        self.pumpMainQueue()

        // The disclosure alert is shown before anything else happens.
        XCTAssertTrue(vm.disclosureAlertShow)
        XCTAssertFalse(vm.monetizationShow)
        XCTAssertNil(vm.asyncRun.error)
        XCTAssertFalse(cache.pdfConvertPrivacyAccepted)

        // Accepting persists the flag, dismisses the alert and advances to the gate.
        vm.onDisclosureAccepted()
        self.pumpMainQueue()
        XCTAssertTrue(cache.pdfConvertPrivacyAccepted)
        XCTAssertFalse(vm.disclosureAlertShow)
        XCTAssertTrue(vm.monetizationShow)
    }

    @MainActor
    func testDisclosureFlagIsSharedWithConvertFlow() {
        // The convert flow having already accepted the disclosure (same cache flag)
        // means the advanced-tool flow skips it entirely and goes straight to the gate.
        let cache = CacheManagerMock()
        let vm = self.makeViewModel(premium: false, disclosureAccepted: true, cache: cache)

        vm.run(pdf: self.makeSinglePagePdf(), tool: .sanitize, onCompleted: nil)
        self.pumpMainQueue()

        XCTAssertFalse(vm.disclosureAlertShow)
        XCTAssertTrue(vm.monetizationShow)
    }

    @MainActor
    func testCancellingDisclosureAbortsTheRun() {
        let cache = CacheManagerMock()
        let vm = self.makeViewModel(premium: true, disclosureAccepted: false, cache: cache)

        vm.run(pdf: self.makeSinglePagePdf(), tool: .repair, onCompleted: nil)
        self.pumpMainQueue()
        XCTAssertTrue(vm.disclosureAlertShow)

        vm.onDisclosureCancelled()
        self.pumpMainQueue()
        XCTAssertFalse(vm.disclosureAlertShow)
        XCTAssertFalse(vm.monetizationShow)
        XCTAssertNil(vm.asyncRun.error)
        // Declining does not silently grant consent.
        XCTAssertFalse(cache.pdfConvertPrivacyAccepted)
    }

    // MARK: - Premium gate

    @MainActor
    func testNonPremiumUserSeesPaywallAndRunIsDeferred() {
        let cache = CacheManagerMock()
        let repository = RepositoryMock()
        // Disclosure already accepted so only the premium gate is exercised.
        let vm = self.makeViewModel(premium: false,
                                    disclosureAccepted: true,
                                    cache: cache,
                                    repository: repository)

        vm.run(pdf: self.makeSinglePagePdf(), tool: .pdfa, onCompleted: nil)
        self.pumpMainQueue()

        XCTAssertTrue(vm.monetizationShow)
        XCTAssertFalse(vm.disclosureAlertShow)
        // No processing attempted, nothing saved while the paywall is up.
        XCTAssertNil(vm.asyncRun.error)
        XCTAssertFalse(vm.asyncRun.isLoading)
        XCTAssertTrue(repository.savedPdfs.isEmpty)
    }

    // MARK: - Success path (network → archive save)

    @MainActor
    func testSuccessSavesProcessedPdfToArchiveAndConfirms() {
        let cache = CacheManagerMock()
        let repository = RepositoryMock()
        let stirling = StirlingMock()
        stirling.resultData = self.makePdfData() // valid PDF bytes returned by the server
        let vm = self.makeViewModel(premium: true,
                                    disclosureAccepted: true,
                                    cache: cache,
                                    repository: repository,
                                    stirling: stirling)

        var onCompletedCalled = false
        let pdf = self.makeSinglePagePdf()
        vm.run(pdf: pdf, tool: .repair, onCompleted: { onCompletedCalled = true })
        self.pumpMainQueue()

        // The processed PDF is saved to the archive with the tool's filename suffix.
        XCTAssertEqual(repository.savedPdfs.count, 1)
        XCTAssertEqual(repository.savedPdfs.first?.filename, pdf.filename + "-repaired")
        // Success is confirmed and the completion (Home → go to archive) is invoked.
        XCTAssertTrue(vm.successAlertShow)
        XCTAssertFalse(vm.successMessage.isEmpty)
        XCTAssertTrue(onCompletedCalled)
        XCTAssertNil(vm.asyncRun.error)
        XCTAssertFalse(vm.asyncRun.isLoading)
        XCTAssertFalse(vm.monetizationShow)
    }

    @MainActor
    func testInvalidPdfDataFromServerSurfacesErrorAndSavesNothing() {
        let cache = CacheManagerMock()
        let repository = RepositoryMock()
        let stirling = StirlingMock()
        stirling.resultData = Data("this is not a pdf".utf8) // mangled server response
        let vm = self.makeViewModel(premium: true,
                                    disclosureAccepted: true,
                                    cache: cache,
                                    repository: repository,
                                    stirling: stirling)

        var onCompletedCalled = false
        vm.run(pdf: self.makeSinglePagePdf(), tool: .sanitize, onCompleted: { onCompletedCalled = true })
        self.pumpMainQueue()

        XCTAssertEqual(vm.asyncRun.error, .invalidResponse)
        XCTAssertTrue(repository.savedPdfs.isEmpty)
        XCTAssertFalse(vm.successAlertShow)
        XCTAssertFalse(onCompletedCalled)
    }

    @MainActor
    func testServerErrorSurfacesAndSavesNothing() {
        let cache = CacheManagerMock()
        let repository = RepositoryMock()
        let stirling = StirlingMock()
        stirling.errorMode = .serverError(message: "boom")
        let vm = self.makeViewModel(premium: true,
                                    disclosureAccepted: true,
                                    cache: cache,
                                    repository: repository,
                                    stirling: stirling)

        vm.run(pdf: self.makeSinglePagePdf(), tool: .pdfa, onCompleted: nil)
        self.pumpMainQueue()

        XCTAssertEqual(vm.asyncRun.error, .serverError(message: "boom"))
        XCTAssertTrue(repository.savedPdfs.isEmpty)
        XCTAssertFalse(vm.successAlertShow)
        XCTAssertFalse(vm.monetizationShow)
    }
}

// MARK: - Mocks

private final class CacheManagerMock: CacheManager {
    var onboardingShown: Bool = false
    var preReviewShown: Bool = false
    var pdfConvertPrivacyAccepted: Bool = false
}

private final class AnalyticsManagerMock: AnalyticsManager {
    func track(event: AnalyticsEvent) {}
}

/// Records saved PDFs and can be forced to throw, so the archive-save step is
/// observable without touching Core Data.
private final class RepositoryMock: Repository {
    private(set) var savedPdfs: [Pdf] = []
    var saveError: Error?

    func savePdf(pdf: Pdf) throws -> Pdf {
        if let saveError = self.saveError { throw saveError }
        self.savedPdfs.append(pdf)
        return pdf
    }
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

/// Synchronous Stirling stub: returns `resultData` (or fails with `errorMode`)
/// immediately, so the success path is testable without the built-in mock's delay.
private final class StirlingMock: StirlingApiManager {
    var available: Bool = true
    var errorMode: StirlingApiError?
    var resultData: Data = Data()
    var suggestedExtension: String = "pdf"

    var isAvailable: Bool { self.available }

    func process(fileData: Data,
                 filename: String,
                 operation: StirlingOperation) -> AnyPublisher<StirlingResult, StirlingApiError> {
        if let errorMode = self.errorMode {
            return Fail(error: errorMode).eraseToAnyPublisher()
        }
        return Just(StirlingResult(data: self.resultData, suggestedFileExtension: self.suggestedExtension))
            .setFailureType(to: StirlingApiError.self)
            .eraseToAnyPublisher()
    }
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
