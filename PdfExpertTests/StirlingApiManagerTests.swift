//
//  StirlingApiManagerTests.swift
//  PdfExpertTests
//
//  Unit tests for the Stirling-PDF client layer. No real network is exercised:
//  request-building and the pure response/error-mapping helpers are tested
//  directly, and the end-to-end `process(...)` path is driven through Moya's
//  immediate stubbing with a custom endpoint closure.
//

import XCTest
import Moya
import CombineMoya
import Combine
@testable import PdfExpert

final class StirlingApiManagerTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        self.cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func target(_ operation: StirlingOperation,
                        baseUrl: String = "https://proxy.example",
                        filename: String = "document") -> StirlingService {
        .process(operation: operation,
                 fileData: Data("%PDF-1.4".utf8),
                 filename: filename,
                 credentials: Self.credentials,
                 baseUrlString: baseUrl)
    }

    private static let credentials = ProxyCredentials(appCheckToken: "APPCHECK",
                                                     originalTransactionId: "1000000000000001")

    /// Builds a MoyaProvider that immediately stubs every request with the given
    /// status/data. When `headers` is provided the stub is delivered as a full
    /// `HTTPURLResponse` so header-driven extension derivation can be exercised.
    private func stubbingProvider(statusCode: Int,
                                  data: Data,
                                  headers: [String: String]? = nil) -> MoyaProvider<StirlingService> {
        let endpointClosure = { (target: StirlingService) -> Endpoint in
            let sampleResponseClosure: () -> EndpointSampleResponse = {
                if let headers = headers {
                    let response = HTTPURLResponse(url: URL(target: target),
                                                   statusCode: statusCode,
                                                   httpVersion: nil,
                                                   headerFields: headers)!
                    return .response(response, data)
                }
                return .networkResponse(statusCode, data)
            }
            return Endpoint(url: URL(target: target).absoluteString,
                            sampleResponseClosure: sampleResponseClosure,
                            method: target.method,
                            task: target.task,
                            httpHeaderFields: target.headers)
        }
        return MoyaProvider<StirlingService>(endpointClosure: endpointClosure,
                                             stubClosure: MoyaProvider.immediatelyStub)
    }

    private func manager(enabled: Bool,
                         provider: MoyaProvider<StirlingService>,
                         proxyUrl: String = "https://proxy.example",
                         credentials: ProxyCredentialsProvider = CredentialsProviderStub()) -> StirlingApiManagerImpl {
        StirlingApiManagerImpl(isEnabledProvider: { enabled },
                               baseUrlProvider: { proxyUrl },
                               credentialsProvider: credentials,
                               provider: provider)
    }

    /// Runs `process(...)` and returns the single completion outcome.
    private func run(_ manager: StirlingApiManagerImpl,
                     operation: StirlingOperation = .pdfToWord) -> Result<StirlingResult, StirlingApiError> {
        let expectation = self.expectation(description: "process completes")
        var outcome: Result<StirlingResult, StirlingApiError>!
        manager.process(fileData: Data("%PDF".utf8), filename: "document", operation: operation)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    outcome = .failure(error)
                    expectation.fulfill()
                }
            }, receiveValue: { result in
                outcome = .success(result)
                expectation.fulfill()
            })
            .store(in: &self.cancellables)
        self.wait(for: [expectation], timeout: 2.0)
        return outcome
    }

    // MARK: - Request building

    /// Every operation asks the proxy for itself by name. These names are the
    /// contract with `proxy/src/upstream.ts`, which holds the Stirling paths — if
    /// one is renamed here without being renamed there, the worker answers 404.
    func testPathPerOperation() {
        for operation in StirlingOperation.allCases {
            XCTAssertEqual(self.target(operation).path, "/v1/stirling/\(operation.rawValue)")
        }
    }

    func testRequestMethodIsPost() {
        XCTAssertEqual(self.target(.pdfToWord).method, .post)
    }

    /// The app presents App Check and the subscription id. It has no service key
    /// to send any more, and sending one would be a bug worth catching.
    func testHeadersCarryProxyCredentialsAndNoServiceKey() {
        let headers = self.target(.pdfToWord).headers
        XCTAssertEqual(headers?["X-App-Check"], "APPCHECK")
        XCTAssertEqual(headers?["X-Original-Transaction-Id"], "1000000000000001")
        XCTAssertNil(headers?["X-API-KEY"])
    }

    /// The path names the operation; the worker owns the mapping to Stirling's
    /// own paths, so the app cannot be talked into reaching another endpoint.
    func testPathNamesTheOperationRatherThanAStirlingPath() {
        XCTAssertEqual(self.target(.sanitize).path, "/v1/stirling/sanitize")
        XCTAssertEqual(self.target(.pdfToWord).path, "/v1/stirling/pdfToWord")
    }

    func testBaseUrlComesFromTarget() {
        XCTAssertEqual(self.target(.pdfToWord, baseUrl: "https://self-hosted.example.com").baseURL.absoluteString,
                       "https://self-hosted.example.com")
    }

    func testMultipartFieldIsFileInputPdf() {
        guard case .uploadMultipart(let parts) = self.target(.pdfToWord).task else {
            return XCTFail("expected an uploadMultipart task")
        }
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts.first?.name, "fileInput")
        XCTAssertEqual(parts.first?.fileName, "document.pdf")
        XCTAssertEqual(parts.first?.mimeType, "application/pdf")
    }

    func testUploadFilenameEnforcesPdfExtension() {
        XCTAssertEqual(StirlingService.uploadFilename(from: "report", operation: .pdfToWord), "report.pdf")
        XCTAssertEqual(StirlingService.uploadFilename(from: "report.pdf", operation: .pdfToWord), "report.pdf")
        XCTAssertEqual(StirlingService.uploadFilename(from: "report.PDF", operation: .pdfToWord), "report.PDF")
        XCTAssertEqual(StirlingService.uploadFilename(from: "   ", operation: .pdfToWord), "document.pdf")
    }

    /// The server picks its LibreOffice converter from the extension, so `.fileToPdf`
    /// must upload the source name untouched.
    func testUploadFilenameKeepsSourceExtensionForFileToPdf() {
        XCTAssertEqual(StirlingService.uploadFilename(from: "report.docx", operation: .fileToPdf), "report.docx")
        XCTAssertEqual(StirlingService.uploadFilename(from: "sheet.xlsx", operation: .fileToPdf), "sheet.xlsx")
        XCTAssertEqual(StirlingService.uploadFilename(from: "   ", operation: .fileToPdf), "document")
    }

    func testMimeTypeFollowsFilenameExtension() {
        XCTAssertEqual(StirlingService.mimeType(forFilename: "report.pdf"), "application/pdf")
        XCTAssertEqual(StirlingService.mimeType(forFilename: "report.docx"),
                       "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        XCTAssertEqual(StirlingService.mimeType(forFilename: "unknown"), "application/octet-stream")
    }

    func testMultipartForFileToPdfCarriesSourceNameAndMimeType() {
        guard case .uploadMultipart(let parts) = self.target(.fileToPdf, filename: "report.docx").task else {
            return XCTFail("expected an uploadMultipart task")
        }
        XCTAssertEqual(parts.first?.fileName, "report.docx")
        XCTAssertEqual(parts.first?.mimeType,
                       "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    }

    // MARK: - Extension derivation (pure)

    func testExtensionFromContentDispositionWins() {
        let ext = StirlingApiManagerImpl.suggestedExtension(
            contentDisposition: "attachment; filename=\"out.docx\"",
            contentType: "application/pdf", // deliberately mismatched to prove disposition wins
            operation: .pdfToPdfa)
        XCTAssertEqual(ext, "docx")
    }

    func testExtensionFromContentDispositionRfc5987() {
        let ext = StirlingApiManagerImpl.suggestedExtension(
            contentDisposition: "attachment; filename*=UTF-8''report%20final.pptx",
            contentType: nil,
            operation: .pdfToWord)
        XCTAssertEqual(ext, "pptx")
    }

    func testExtensionFromContentTypeFallback() {
        let ext = StirlingApiManagerImpl.suggestedExtension(
            contentDisposition: nil,
            contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            operation: .repair)
        XCTAssertEqual(ext, "docx")
    }

    func testExtensionFromContentTypeCsvIgnoresParameters() {
        let ext = StirlingApiManagerImpl.suggestedExtension(
            contentDisposition: nil,
            contentType: "text/csv; charset=utf-8",
            operation: .pdfToCsv)
        XCTAssertEqual(ext, "csv")
    }

    func testExtensionOperationDefaultFallback() {
        XCTAssertEqual(StirlingApiManagerImpl.suggestedExtension(contentDisposition: nil, contentType: nil, operation: .pdfToWord), "docx")
        XCTAssertEqual(StirlingApiManagerImpl.suggestedExtension(contentDisposition: nil, contentType: nil, operation: .pdfToPresentation), "pptx")
        XCTAssertEqual(StirlingApiManagerImpl.suggestedExtension(contentDisposition: nil, contentType: nil, operation: .pdfToCsv), "csv")
        XCTAssertEqual(StirlingApiManagerImpl.suggestedExtension(contentDisposition: nil, contentType: nil, operation: .pdfToPdfa), "pdf")
        XCTAssertEqual(StirlingApiManagerImpl.suggestedExtension(contentDisposition: nil, contentType: nil, operation: .repair), "pdf")
        XCTAssertEqual(StirlingApiManagerImpl.suggestedExtension(contentDisposition: nil, contentType: nil, operation: .sanitize), "pdf")
        XCTAssertEqual(StirlingApiManagerImpl.suggestedExtension(contentDisposition: nil, contentType: nil, operation: .fileToPdf), "pdf")
    }

    func testExtensionZipFromContentType() {
        let ext = StirlingApiManagerImpl.suggestedExtension(contentDisposition: nil,
                                                            contentType: "application/zip",
                                                            operation: .pdfToCsv)
        XCTAssertEqual(ext, "zip")
    }

    // MARK: - Error mapping (pure)

    func testStatusCodeUnauthorizedMapsToInvalidApiKey() {
        XCTAssertEqual(StirlingApiManagerImpl.error(forStatusCode: 401, data: Data()), .invalidApiKey)
        XCTAssertEqual(StirlingApiManagerImpl.error(forStatusCode: 403, data: Data()), .invalidApiKey)
    }

    func testStatusCodeServerErrorExtractsMessage() {
        let body = Data(#"{"error":"Unsupported file"}"#.utf8)
        XCTAssertEqual(StirlingApiManagerImpl.error(forStatusCode: 500, data: body),
                       .serverError(message: "Unsupported file"))
    }

    func testServerErrorMessageParsing() {
        XCTAssertEqual(StirlingApiManagerImpl.serverErrorMessage(from: Data(#"{"error":"boom"}"#.utf8)), "boom")
        XCTAssertEqual(StirlingApiManagerImpl.serverErrorMessage(from: Data(#"{"message":"nope"}"#.utf8)), "nope")
        XCTAssertEqual(StirlingApiManagerImpl.serverErrorMessage(from: Data("Plain failure".utf8)), "Plain failure")
        XCTAssertNil(StirlingApiManagerImpl.serverErrorMessage(from: Data()))
    }

    func testUrlErrorMapping() {
        XCTAssertEqual(StirlingApiManagerImpl.mapUrlError(URLError(.timedOut)), .timeout)
        XCTAssertEqual(StirlingApiManagerImpl.mapUrlError(URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(StirlingApiManagerImpl.mapUrlError(URLError(.networkConnectionLost)), .offline)
    }

    func testMapErrorPassesThroughStirlingError() {
        XCTAssertEqual(StirlingApiManagerImpl.mapError(StirlingApiError.notConfigured), .notConfigured)
    }

    // MARK: - End-to-end via stubbing

    func testSuccessDerivesExtensionFromContentDispositionHeader() {
        let provider = self.stubbingProvider(statusCode: 200,
                                             data: Data("binary".utf8),
                                             headers: ["Content-Disposition": "attachment; filename=\"out.docx\""])
        let outcome = self.run(self.manager(enabled: true, provider: provider))
        switch outcome {
        case .success(let result):
            XCTAssertEqual(result.suggestedFileExtension, "docx")
            XCTAssertEqual(result.data, Data("binary".utf8))
        case .failure(let error):
            XCTFail("expected success, got \(error)")
        }
    }

    func testSuccessDerivesExtensionFromContentTypeHeader() {
        let provider = self.stubbingProvider(statusCode: 200,
                                             data: Data("binary".utf8),
                                             headers: ["Content-Type": "text/csv"])
        let outcome = self.run(self.manager(enabled: true, provider: provider), operation: .pdfToCsv)
        XCTAssertEqual(try? outcome.get().suggestedFileExtension, "csv")
    }

    func testSuccessFallsBackToOperationDefaultWhenNoHeaders() {
        let provider = self.stubbingProvider(statusCode: 200, data: Data("binary".utf8))
        let outcome = self.run(self.manager(enabled: true, provider: provider), operation: .pdfToPresentation)
        XCTAssertEqual(try? outcome.get().suggestedFileExtension, "pptx")
    }

    func testUnauthorizedMapsToInvalidApiKey() {
        let provider = self.stubbingProvider(statusCode: 401, data: Data())
        let outcome = self.run(self.manager(enabled: true, provider: provider))
        XCTAssertEqual(self.error(from: outcome), .invalidApiKey)
    }

    func testServerErrorWithJsonBodyMapsToServerError() {
        let provider = self.stubbingProvider(statusCode: 500, data: Data(#"{"error":"Conversion failed"}"#.utf8))
        let outcome = self.run(self.manager(enabled: true, provider: provider))
        XCTAssertEqual(self.error(from: outcome), .serverError(message: "Conversion failed"))
    }

    func testNotConfiguredWhenNoProxyIsDeployed() {
        let provider = self.stubbingProvider(statusCode: 200, data: Data())
        let outcome = self.run(self.manager(enabled: true, provider: provider, proxyUrl: ""))
        XCTAssertEqual(self.error(from: outcome), .notConfigured)
    }

    /// A subscriber whose subscription has lapsed never reaches the network: the
    /// credentials cannot be built, and the error says why.
    func testFailsWithoutCredentialsRatherThanCallingTheProxy() {
        let provider = self.stubbingProvider(statusCode: 200, data: Data())
        let stub = CredentialsProviderStub(error: ProxyCredentialsError.notSubscribed)
        let outcome = self.run(self.manager(enabled: true, provider: provider, credentials: stub))
        XCTAssertNotNil(self.error(from: outcome))
    }

    func testNotConfiguredWhenKillSwitchOff() {
        let provider = self.stubbingProvider(statusCode: 200, data: Data())
        let outcome = self.run(self.manager(enabled: false, provider: provider))
        XCTAssertEqual(self.error(from: outcome), .notConfigured)
    }

    private func error(from outcome: Result<StirlingResult, StirlingApiError>) -> StirlingApiError? {
        if case .failure(let error) = outcome { return error }
        return nil
    }
}

/// Hands out fixed credentials, or refuses, without Firebase or StoreKit.
private final class CredentialsProviderStub: ProxyCredentialsProvider {

    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    var canAuthenticate: Bool { self.error == nil }

    func credentials() async throws -> ProxyCredentials {
        if let error = self.error { throw error }
        return ProxyCredentials(appCheckToken: "APPCHECK", originalTransactionId: "1000000000000001")
    }
}
