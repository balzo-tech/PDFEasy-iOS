//
//  ChatPdfManagerImpl.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/07/23.
//

import Foundation
import Moya
import CombineMoya
import Combine

fileprivate struct ChatPdfApiError: Decodable, CustomStringConvertible {
    let code: String
    let message: String
    
    var description: String { self.message }
}

class ChatPdfManagerImpl: ChatPdfManager {
    
    fileprivate static let baseUrl: String = "https://api.chatpdf.com"
    
    fileprivate static let apiKey: String = { ProjectInfo.chatPdfApiKey }()
    
    lazy var provider: MoyaProvider<ChatPdfService> = { self.createProvider() }()
    
    lazy var loggerPlugin: PluginType = {
        let formatter = NetworkLoggerPlugin.Configuration.Formatter(requestData: Data.JSONRequestDataFormatter,
                                                                    responseData: Data.JSONRequestDataFormatter)
        let logOptions: NetworkLoggerPlugin.Configuration.LogOptions = K.Test.ChatPdf.NetworkLogVerbose
            ? .verbose
            : .default
        let config = NetworkLoggerPlugin.Configuration(formatter: formatter, logOptions: logOptions)
        return NetworkLoggerPlugin(configuration: config)
    }()
    
    func createProvider() -> MoyaProvider<ChatPdfService> {
        MoyaProvider<ChatPdfService>(plugins: [self.loggerPlugin])
    }
    
    func sendPdf(pdf: Data) -> AnyPublisher<ChatPdfRef, ChatPdfError> {
        self.send(request: .sendPdf(pdf: pdf))
    }
    
    func generateText(ref: ChatPdfRef, prompt: String) -> AnyPublisher<ChatPdfMessage, ChatPdfError> {
        self.send(request: .generateText(ref: ref, prompt: prompt))
    }
    
    private func send<T: Decodable>(request: ChatPdfService) -> AnyPublisher<T, ChatPdfError> {
        self.provider.requestPublisher(request)
            .tryMap() { response -> Data in
                guard 200 ... 299 ~= response.statusCode else {
                    let decoder = JSONDecoder()
                    if let apiError =  try? decoder.decode(ChatPdfApiError.self, from: response.data) {
                        throw ChatPdfError.underlyingError(errorDescription: apiError.description)
                    } else {
                        throw ChatPdfError.underlyingError(errorDescription: String(data: response.data, encoding: .utf8) ?? "")
                    }
                }
                return response.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let error = error as? ChatPdfError {
                    return error
                } else if let error = error as? DecodingError {
                    return ChatPdfError.parse
                } else {
                    return ChatPdfError.underlyingError(errorDescription: error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
}

enum ChatPdfService {
    // Misc
    case sendPdf(pdf: Data)
    case generateText(ref: ChatPdfRef, prompt: String)
}

extension ChatPdfService: TargetType {
    
    var baseURL: URL { return URL(string: ChatPdfManagerImpl.baseUrl)! }
    
    var path: String {
        switch self {
        case .sendPdf: return "/v1/sources/add-file"
        case .generateText: return "/v1/chats/message"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .sendPdf, .generateText:
            return .post
        }
    }
    
    var sampleData: Data {
        switch self {
        // Misc
        case .sendPdf: return "{\"sourceId\": \"TestSourceId\"}".utf8Encoded
        case .generateText: return "{\"content\": \"Test Message\"}".utf8Encoded
        }
    }
    
    var task: Task {
        switch self {
        case .sendPdf:
            return .uploadMultipart(self.multipartBody)
        case .generateText(let ref, let prompt):
            let message: [String: Any] = [
                "role": "user",
                "content": prompt
            ]
            let parameters: [String: Any] = [
                "sourceId": ref.sourceId,
                "messages": [message]
            ]
            return .requestParameters(parameters: parameters, encoding: JSONEncoding.default)
        }
    }
    
    var multipartBody: [MultipartFormData] {
        switch self {
        case .sendPdf(let pdfFile):
            let imageDataProvider = MultipartFormData(provider: MultipartFormData.FormDataProvider.data(pdfFile),
                                                      name: "pdf_expert_file",
                                                      fileName: "pdf_expert_file.pdf",
                                                      mimeType: "application/pdf")
            return [imageDataProvider]
        default:
            return []
        }
    }
    
    var headers: [String: String]? {
        return [
            "Content-type": "application/json",
            "x-api-key": ChatPdfManagerImpl.apiKey
        ]
    }
}
