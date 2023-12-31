//
//  ChatPdfManager.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import Factory
import Combine

enum ChatPdfError: LocalizedError, UnderlyingError {
    case unknownError
    case parse
    case pdfTooLarge
    case pdfTooManyPages
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError, .parse: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        case .pdfTooLarge: return "Your pdf is too large"
        case .pdfTooManyPages: return "Your pdf has too many pages"
        }
    }
}


protocol ChatPdfManager {
    func sendPdf(pdf: Data) -> AnyPublisher<ChatPdfRef, ChatPdfError>
    func generateText(ref: ChatPdfRef, prompt: String) -> AnyPublisher<ChatPdfMessage, ChatPdfError>
    func getSetupData(ref: ChatPdfRef) -> AnyPublisher<ChatPdfSetupData, ChatPdfError>
    func deletePdf(ref: ChatPdfRef)
}

extension Container {
    var chatPdfManager: Factory<ChatPdfManager> {
        self {
            #if DEBUG
            K.Test.ChatPdf.UseMock ? (ChatPdfManagerMock() as ChatPdfManager) : (ChatPdfManagerImpl() as ChatPdfManager)
            #else
            ChatPdfManagerImpl()
            #endif
        }.singleton
    }
}
