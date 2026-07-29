//
//  StirlingApiManager.swift
//  PdfExpert
//
//  Client layer for the Stirling-PDF Processing API (document conversion &
//  repair/sanitize). Uploads a PDF as multipart form-data and receives the
//  processed document back as a BINARY response body. Errors on non-2xx come
//  back as JSON or plain text.
//
//  Requests go to the Cloudflare Worker in `proxy/`, never to Stirling directly:
//  the service key lives there and the app has none. What it sends instead is an
//  App Check token and the id of its subscription, which the worker checks with
//  Apple before spending anything — see `ProxyCredentials` and
//  `proxy/README.md`. The `stirling_api_enabled` remote-config kill switch still
//  applies on top, so the feature can be turned off without shipping a build.
//

import Foundation
import Factory
import Combine

/// The set of Stirling-PDF endpoints this client exposes. `rawValue` is only used
/// for logging / mock output labels; the HTTP path is resolved in the TargetType.
enum StirlingOperation: String, CaseIterable {
    case pdfToWord
    case pdfToPresentation
    case pdfToCsv
    case pdfToPdfa
    case repair
    case sanitize
    /// Office / iWork document → PDF (LibreOffice server-side). The only operation
    /// whose *input* is not a PDF: it backs the high-fidelity fallback offered when
    /// the on-device WebKit conversion cannot render a document.
    case fileToPdf

    /// What the proxy is asked for. The worker keeps the table of Stirling paths,
    /// so these names have to match the keys in `proxy/src/upstream.ts`.
    var proxyName: String { self.rawValue }
}

/// A successful Stirling response: the raw processed document plus the file
/// extension the caller should use when saving/sharing it (resolved from the
/// response headers, falling back to an operation default).
struct StirlingResult: Equatable {
    let data: Data
    let suggestedFileExtension: String   // "docx", "pptx", "csv", "zip", "pdf"
}

/// User-facing errors. Lives here (next to the protocol) rather than in
/// SharedErrors.swift to mirror the existing convention where each network
/// manager keeps its error enum beside its protocol (see `ChatPdfError` in
/// `ChatPdfManager.swift`). `Equatable` is synthesized so tests can assert on
/// the exact case (including the `serverError` message).
enum StirlingApiError: LocalizedError, Equatable {
    /// Kill switch off or missing/empty API key.
    case notConfigured
    /// 401 / 403 from the API.
    case invalidApiKey
    /// Other 4xx/5xx, carrying the API's error message when it could be parsed.
    case serverError(message: String?)
    case timeout
    case offline
    case invalidResponse
    case unknownError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "This conversion tool is currently unavailable. Please try again later.")
        case .invalidApiKey:
            return String(localized: "The conversion service rejected the request. Please try again later.")
        case .serverError(let message):
            if let message = message, !message.isEmpty {
                return message
            }
            return String(localized: "The conversion could not be completed. Please try again.")
        case .timeout:
            return String(localized: "The conversion timed out. Please try again with a smaller document.")
        case .offline:
            return String(localized: "You appear to be offline. Please check your connection and try again.")
        case .invalidResponse:
            return String(localized: "The conversion service returned an unexpected response. Please try again.")
        case .unknownError:
            return String(localized: "Internal Error. Please try again later")
        }
    }
}

protocol StirlingApiManager {
    /// Both the remote-config kill switch and a deployed proxy are required.
    var isAvailable: Bool { get }
    /// Uploads `fileData` and returns the processed document. `filename` names the
    /// multipart part: for PDF-in operations a `.pdf` extension is enforced, while
    /// `.fileToPdf` keeps the source extension — LibreOffice picks its converter
    /// from it, so stripping it would break the conversion.
    func process(fileData: Data,
                 filename: String,
                 operation: StirlingOperation) -> AnyPublisher<StirlingResult, StirlingApiError>
}

extension Container {
    var stirlingApiManager: Factory<StirlingApiManager> {
        self {
            #if DEBUG
            K.Test.Stirling.UseMock
                ? (StirlingApiManagerMock() as StirlingApiManager)
                : (StirlingApiManagerImpl() as StirlingApiManager)
            #else
            StirlingApiManagerImpl()
            #endif
        }.singleton
    }
}
