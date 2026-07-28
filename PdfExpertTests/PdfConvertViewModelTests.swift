//
//  PdfConvertViewModelTests.swift
//  PdfExpertTests
//
//  Unit tests for the PDF → Word / PowerPoint / Excel conversion flow. The pure
//  parts (format → operation mapping, output-filename building) are tested directly.
//  The stateful flow (one-time privacy disclosure, premium gate) is driven through a
//  fully-instantiated view model whose dependencies are replaced with lightweight
//  mocks registered on the Factory container.
//

import XCTest
import Combine
import StoreKit
import Factory
import PDFKit
@testable import PdfExpert

final class PdfConvertViewModelTests: XCTestCase {

    private var createdUrls: [URL] = []

    override func tearDown() {
        PdfConvertViewModel.cleanupFiles(self.createdUrls)
        self.createdUrls = []
        // Restore the real dependencies so other test cases are unaffected.
        Container.shared.store.reset()
        Container.shared.cacheManager.reset()
        Container.shared.analyticsManager.reset()
        Container.shared.stirlingApiManager.reset()
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A single-page PDF with real content (non-nil `rawData`, `pageCount == 1`).
    private func makeSinglePagePdf() -> Pdf {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            ("Convert me" as NSString).draw(at: CGPoint(x: 50, y: 50),
                                            withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        return Pdf(pdfDocument: PDFDocument(data: data) ?? PDFDocument())
    }

    /// Registers the mocked dependencies and returns a fresh view model. `@Injected`
    /// resolves eagerly at init, so the mocks must be registered first.
    @MainActor
    private func makeViewModel(premium: Bool,
                              disclosureAccepted: Bool,
                              cache: CacheManagerMock,
                              stirlingError: StirlingApiError? = nil) -> PdfConvertViewModel {
        let store = StoreMock()
        store.isPremium.value = premium
        let stirling = StirlingApiManagerMock()
        stirling.errorMode = stirlingError
        cache.pdfConvertPrivacyAccepted = disclosureAccepted
        Container.shared.store.register { store }
        Container.shared.cacheManager.register { cache }
        Container.shared.analyticsManager.register { AnalyticsManagerMock() }
        Container.shared.stirlingApiManager.register { stirling }
        return PdfConvertViewModel()
    }

    /// Spins the main run loop once so deferred (`DispatchQueue.main.async`) work runs.
    private func pumpMainQueue() {
        let exp = expectation(description: "pump main queue")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - Pure: format → operation mapping

    func testFormatMapsToStirlingOperation() {
        XCTAssertEqual(PdfConvertFormat.word.operation, .pdfToWord)
        XCTAssertEqual(PdfConvertFormat.powerpoint.operation, .pdfToPresentation)
        XCTAssertEqual(PdfConvertFormat.csv.operation, .pdfToCsv)
    }

    func testFormatDefaultOutputExtensions() {
        XCTAssertEqual(StirlingApiManagerImpl.defaultExtension(for: PdfConvertFormat.word.operation), "docx")
        XCTAssertEqual(StirlingApiManagerImpl.defaultExtension(for: PdfConvertFormat.powerpoint.operation), "pptx")
        XCTAssertEqual(StirlingApiManagerImpl.defaultExtension(for: PdfConvertFormat.csv.operation), "csv")
    }

    func testEveryFormatHasDisplayMetadata() {
        for format in PdfConvertFormat.allCases {
            XCTAssertFalse(format.displayName.isEmpty)
            XCTAssertFalse(format.systemImageName.isEmpty)
            XCTAssertFalse(format.outputDescription.isEmpty)
        }
    }

    // MARK: - Pure: output filename / extension handling

    func testOutputURLSanitizesFilenameAndUsesSuggestedExtension() {
        let url = PdfConvertViewModel.outputURL(baseName: "my/report:2024*final", fileExtension: "docx")
        XCTAssertEqual(url.pathExtension, "docx")
        XCTAssertEqual(url.deletingPathExtension().lastPathComponent, "my_report_2024_final")
    }

    func testSanitizedFilenameFallsBackForEmptyName() {
        XCTAssertEqual(PdfConvertViewModel.sanitizedFilename(""), "document")
        XCTAssertEqual(PdfConvertViewModel.sanitizedFilename("   "), "document")
    }

    func testWriteResultPersistsDataWithSuggestedExtension() throws {
        let payload = Data("mock,csv,payload".utf8)
        let result = StirlingResult(data: payload, suggestedFileExtension: "csv")
        let url = try PdfConvertViewModel.writeResult(result, baseName: "quarterly report")
        self.createdUrls.append(url)
        XCTAssertEqual(url.pathExtension, "csv")
        XCTAssertEqual(url.deletingPathExtension().lastPathComponent, "quarterly report")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), payload)
    }

    // MARK: - Privacy disclosure (one-time)

    @MainActor
    func testFirstConversionRequiresDisclosureAndPersistsOnAccept() {
        let cache = CacheManagerMock()
        // First ever conversion: disclosure not yet accepted. Non-premium so the flow
        // stops at the paywall after acceptance (never hitting the network), keeping
        // the assertions deterministic and focused on the disclosure behaviour.
        let vm = self.makeViewModel(premium: false, disclosureAccepted: false, cache: cache)

        vm.convert(pdf: self.makeSinglePagePdf(), format: .word)
        self.pumpMainQueue()

        // The disclosure alert is shown before anything else happens.
        XCTAssertTrue(vm.disclosureAlertShow)
        XCTAssertFalse(vm.monetizationShow)
        XCTAssertNil(vm.asyncConvert.error)
        XCTAssertFalse(cache.pdfConvertPrivacyAccepted)

        // Accepting persists the flag, dismisses the alert and advances to the gate.
        vm.onDisclosureAccepted()
        self.pumpMainQueue()
        XCTAssertTrue(cache.pdfConvertPrivacyAccepted)
        XCTAssertFalse(vm.disclosureAlertShow)
        XCTAssertTrue(vm.monetizationShow)

        // A second conversion (flag now persisted) skips the disclosure entirely and
        // goes straight to the premium gate.
        let secondVm = PdfConvertViewModel() // same registered (accepted) cache
        secondVm.convert(pdf: self.makeSinglePagePdf(), format: .powerpoint)
        self.pumpMainQueue()
        XCTAssertFalse(secondVm.disclosureAlertShow)
        XCTAssertTrue(secondVm.monetizationShow)
    }

    @MainActor
    func testCancellingDisclosureAbortsTheConversion() {
        let cache = CacheManagerMock()
        let vm = self.makeViewModel(premium: true, disclosureAccepted: false, cache: cache)

        vm.convert(pdf: self.makeSinglePagePdf(), format: .csv)
        self.pumpMainQueue()
        XCTAssertTrue(vm.disclosureAlertShow)

        vm.onDisclosureCancelled()
        self.pumpMainQueue()
        XCTAssertFalse(vm.disclosureAlertShow)
        XCTAssertFalse(vm.monetizationShow)
        XCTAssertNil(vm.asyncConvert.error)
        // Declining does not silently grant consent.
        XCTAssertFalse(cache.pdfConvertPrivacyAccepted)
    }

    // MARK: - Premium gate

    @MainActor
    func testNonPremiumUserSeesPaywallAndConversionIsDeferred() {
        let cache = CacheManagerMock()
        // Disclosure already accepted so only the premium gate is exercised.
        let vm = self.makeViewModel(premium: false, disclosureAccepted: true, cache: cache)

        vm.convert(pdf: self.makeSinglePagePdf(), format: .word)
        self.pumpMainQueue()

        XCTAssertTrue(vm.monetizationShow)
        XCTAssertFalse(vm.disclosureAlertShow)
        // No conversion attempted while the paywall is up.
        XCTAssertNil(vm.asyncConvert.error)
        XCTAssertFalse(vm.asyncConvert.isLoading)
    }

    @MainActor
    func testPremiumUserProceedsStraightToConversion() {
        let cache = CacheManagerMock()
        // Premium + disclosure accepted: the flow reaches the network layer. The
        // Stirling mock is forced to fail synchronously so we can assert the request
        // was attempted without waiting on a real conversion.
        let vm = self.makeViewModel(premium: true,
                                    disclosureAccepted: true,
                                    cache: cache,
                                    stirlingError: .serverError(message: "boom"))

        vm.convert(pdf: self.makeSinglePagePdf(), format: .word)
        self.pumpMainQueue()

        // No paywall for a subscriber; the conversion was attempted and surfaced its error.
        XCTAssertFalse(vm.monetizationShow)
        XCTAssertFalse(vm.disclosureAlertShow)
        XCTAssertEqual(vm.asyncConvert.error, .serverError(message: "boom"))
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
