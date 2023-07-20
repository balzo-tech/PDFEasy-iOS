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
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError, .parse: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        }
    }
}


protocol ChatPdfManager {
    func sendPdf(pdf: Data) -> AnyPublisher<ChatPdfRef, ChatPdfError>
    func generateText(ref: ChatPdfRef, prompt: String) -> AnyPublisher<ChatPdfMessage, ChatPdfError>
}

extension Container {
    var chatPdfManager: Factory<ChatPdfManager> {
        self {
            #if DEBUG
            K.Test.UseMockChatPdf ? (ChatPdfManagerMock() as ChatPdfManager) : (ChatPdfManagerImpl() as ChatPdfManager)
            #else
            ChatPdfManagerImpl()
            #endif
        }.singleton
    }
}
