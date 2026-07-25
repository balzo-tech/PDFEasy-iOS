//
//  StirlingApiManagerImpl.swift
//  PdfExpert
//
//  Moya-backed implementation of `StirlingApiManager`. The heavy-lifting response
//  interpretation (file-extension derivation, HTTP-status → error mapping, error
//  message extraction) is factored into pure `static` functions so it can be
//  unit-tested directly without a live server. The availability inputs (API key,
//  kill switch, base URL) and the MoyaProvider are injectable so `process(...)`
//  can be exercised against Moya's immediate stubbing.
//

import Foundation
import Moya
import CombineMoya
import Combine
import Alamofire
import Factory
import UniformTypeIdentifiers

class StirlingApiManagerImpl: StirlingApiManager {

    // MARK: Injectable inputs

    private let apiKey: String
    private let isEnabledProvider: () -> Bool
    private let baseUrlProvider: () -> String
    private let provider: MoyaProvider<StirlingService>

    /// The defaults wire up the production inputs. Every dependency is injectable so
    /// tests can drive `process(...)` with a stubbed provider and forced availability
    /// without touching Firebase, `ProjectInfo`, or the network.
    init(apiKey: String = ProjectInfo.stirlingApiKey,
         isEnabledProvider: @escaping () -> Bool = { Container.shared.configService().remoteConfigData.value.stirlingApiEnabled },
         baseUrlProvider: @escaping () -> String = { Container.shared.configService().remoteConfigData.value.stirlingApiBaseUrl },
         provider: MoyaProvider<StirlingService>? = nil) {
        self.apiKey = apiKey
        self.isEnabledProvider = isEnabledProvider
        self.baseUrlProvider = baseUrlProvider
        self.provider = provider ?? Self.makeProvider()
    }

    // MARK: - StirlingApiManager

    var isAvailable: Bool {
        self.isEnabledProvider() && !self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func process(fileData: Data,
                 filename: String,
                 operation: StirlingOperation) -> AnyPublisher<StirlingResult, StirlingApiError> {
        guard self.isAvailable else {
            return Fail(error: StirlingApiError.notConfigured).eraseToAnyPublisher()
        }
        let target = StirlingService.process(operation: operation,
                                             fileData: fileData,
                                             filename: filename,
                                             apiKey: self.apiKey,
                                             baseUrlString: self.baseUrlProvider())
        return self.provider.requestPublisher(target)
            .tryMap { try Self.mapResponse($0, operation: operation) }
            .mapError { Self.mapError($0) }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Provider

    /// A dedicated session with a generous request timeout: these conversions can be
    /// long-running, so the default 60s is too aggressive.
    static func makeProvider() -> MoyaProvider<StirlingService> {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = K.Stirling.RequestTimeout
        configuration.timeoutIntervalForResource = K.Stirling.RequestTimeout
        let session = Session(configuration: configuration, startRequestsImmediately: false)
        let logOptions: NetworkLoggerPlugin.Configuration.LogOptions = K.Test.Stirling.NetworkLogVerbose
            ? .verbose
            : .default
        let logger = NetworkLoggerPlugin(configuration: .init(logOptions: logOptions))
        return MoyaProvider<StirlingService>(session: session, plugins: [logger])
    }

    // MARK: - Response mapping (pure, unit-testable)

    /// Turns a raw Moya response into a `StirlingResult`, throwing a mapped
    /// `StirlingApiError` on any non-2xx status.
    static func mapResponse(_ response: Moya.Response, operation: StirlingOperation) throws -> StirlingResult {
        guard 200 ... 299 ~= response.statusCode else {
            throw self.error(forStatusCode: response.statusCode, data: response.data)
        }
        let contentDisposition = response.response?.value(forHTTPHeaderField: "Content-Disposition")
        let contentType = response.response?.value(forHTTPHeaderField: "Content-Type")
        let ext = self.suggestedExtension(contentDisposition: contentDisposition,
                                          contentType: contentType,
                                          operation: operation)
        return StirlingResult(data: response.data, suggestedFileExtension: ext)
    }

    /// 401/403 → `invalidApiKey`; every other non-2xx → `serverError` with a message
    /// extracted from the body when possible.
    static func error(forStatusCode statusCode: Int, data: Data) -> StirlingApiError {
        switch statusCode {
        case 401, 403:
            return .invalidApiKey
        default:
            return .serverError(message: self.serverErrorMessage(from: data))
        }
    }

    /// Best-effort extraction of a human-readable message from an error body:
    /// JSON (`error` / `message` / `detail`, string or nested `{message}`) first,
    /// then a short plain-text fallback.
    static func serverErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            for key in ["error", "message", "detail", "title"] {
                if let value = json[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value
                }
                if let nested = json[key] as? [String: Any],
                   let message = nested["message"] as? String,
                   !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return message
                }
            }
        }
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.count <= 500 {
                return trimmed
            }
        }
        return nil
    }

    // MARK: - File-extension derivation (pure, unit-testable)

    /// Content-Disposition filename extension wins; then a Content-Type mapping;
    /// then the operation's default output extension.
    static func suggestedExtension(contentDisposition: String?,
                                   contentType: String?,
                                   operation: StirlingOperation) -> String {
        if let ext = self.fileExtension(fromContentDisposition: contentDisposition) {
            return ext
        }
        if let ext = self.fileExtension(fromContentType: contentType) {
            return ext
        }
        return self.defaultExtension(for: operation)
    }

    static func fileExtension(fromContentDisposition disposition: String?) -> String? {
        guard let filename = self.filename(fromContentDisposition: disposition) else { return nil }
        let ext = (filename as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    /// Parses the `filename` (or RFC 5987 `filename*`) token out of a
    /// Content-Disposition header value.
    static func filename(fromContentDisposition disposition: String?) -> String? {
        guard let disposition = disposition else { return nil }
        for rawComponent in disposition.components(separatedBy: ";") {
            let component = rawComponent.trimmingCharacters(in: .whitespaces)
            let lower = component.lowercased()
            if lower.hasPrefix("filename*=") {
                var value = String(component.dropFirst("filename*=".count))
                if let range = value.range(of: "''") {
                    value = String(value[range.upperBound...])
                }
                value = value.removingPercentEncoding ?? value
                let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return cleaned.isEmpty ? nil : cleaned
            }
            if lower.hasPrefix("filename=") {
                let value = String(component.dropFirst("filename=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    static func fileExtension(fromContentType contentType: String?) -> String? {
        guard let contentType = contentType else { return nil }
        let mime = (contentType.components(separatedBy: ";").first ?? contentType)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        switch mime {
        case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return "docx"
        case "application/vnd.openxmlformats-officedocument.presentationml.presentation":
            return "pptx"
        case "text/csv":
            return "csv"
        case "application/zip", "application/x-zip-compressed":
            return "zip"
        case "application/pdf":
            return "pdf"
        default:
            return nil
        }
    }

    static func defaultExtension(for operation: StirlingOperation) -> String {
        switch operation {
        case .pdfToWord: return "docx"
        case .pdfToPresentation: return "pptx"
        case .pdfToCsv: return "csv"
        case .pdfToPdfa, .repair, .sanitize, .fileToPdf: return "pdf"
        }
    }

    // MARK: - Error mapping (pure, unit-testable)

    static func mapError(_ error: Error) -> StirlingApiError {
        if let stirlingError = error as? StirlingApiError {
            return stirlingError
        }
        if let urlError = self.urlError(from: error) {
            return self.mapUrlError(urlError)
        }
        if let moyaError = error as? MoyaError, let response = moyaError.response {
            return self.error(forStatusCode: response.statusCode, data: response.data)
        }
        return .unknownError
    }

    /// Digs a `URLError` out of a bare error or a Moya/Alamofire wrapper.
    static func urlError(from error: Error) -> URLError? {
        if let urlError = error as? URLError {
            return urlError
        }
        if let moyaError = error as? MoyaError, case let .underlying(underlying, _) = moyaError {
            if let urlError = underlying as? URLError {
                return urlError
            }
            if let afError = underlying.asAFError,
               let urlError = afError.underlyingError as? URLError {
                return urlError
            }
        }
        return nil
    }

    static func mapUrlError(_ error: URLError) -> StirlingApiError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .offline
        default:
            return .unknownError
        }
    }
}

// MARK: - Moya target

enum StirlingService {
    /// `apiKey` and `baseUrlString` are carried on the case so the target is fully
    /// self-describing (and unit-testable) without reaching into `ProjectInfo` or
    /// the config service.
    case process(operation: StirlingOperation,
                 fileData: Data,
                 filename: String,
                 apiKey: String,
                 baseUrlString: String)
}

extension StirlingService: TargetType {

    var baseURL: URL {
        switch self {
        case let .process(_, _, _, _, baseUrlString):
            return URL(string: baseUrlString) ?? URL(string: K.Stirling.DefaultBaseUrl)!
        }
    }

    var path: String {
        switch self {
        case let .process(operation, _, _, _, _):
            switch operation {
            case .pdfToWord: return "/api/v1/convert/pdf/word"
            case .pdfToPresentation: return "/api/v1/convert/pdf/presentation"
            case .pdfToCsv: return "/api/v1/convert/pdf/csv"
            case .pdfToPdfa: return "/api/v1/convert/pdf/pdfa"
            case .repair: return "/api/v1/misc/repair"
            case .sanitize: return "/api/v1/security/sanitize-pdf"
            case .fileToPdf: return "/api/v1/convert/file/pdf"
            }
        }
    }

    var method: Moya.Method { .post }

    var sampleData: Data { Data() }

    var task: Task {
        switch self {
        case let .process(operation, fileData, filename, _, _):
            let uploadFilename = Self.uploadFilename(from: filename, operation: operation)
            let formData = MultipartFormData(provider: .data(fileData),
                                             name: "fileInput",
                                             fileName: uploadFilename,
                                             mimeType: Self.mimeType(forFilename: uploadFilename))
            return .uploadMultipart([formData])
        }
    }

    var headers: [String: String]? {
        switch self {
        case let .process(_, _, _, apiKey, _):
            return ["X-API-KEY": apiKey]
        }
    }

    /// Names the multipart part. PDF-in operations get a `.pdf` extension enforced;
    /// `.fileToPdf` keeps whatever extension the source carried, because the server
    /// selects its LibreOffice converter from it (a `.docx` renamed to `.pdf` fails).
    static func uploadFilename(from filename: String, operation: StirlingOperation) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "document" : trimmed
        guard operation != .fileToPdf else { return base }
        return (base as NSString).pathExtension.lowercased() == "pdf" ? base : base + ".pdf"
    }

    /// MIME type derived from the upload filename's extension, so an uploaded `.docx`
    /// is not announced as `application/pdf`.
    static func mimeType(forFilename filename: String) -> String {
        let ext = (filename as NSString).pathExtension
        guard !ext.isEmpty,
              let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mimeType
    }
}
