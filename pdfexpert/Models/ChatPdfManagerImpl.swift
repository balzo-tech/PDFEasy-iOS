//
//  ChatPdfManagerImpl.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import Combine

class ChatPdfManagerImpl: ChatPdfManager {
    
    private let apiKey: String
    
    init() {
        self.apiKey = ProjectInfo.chatPdfApiKey
    }
    
    func sendPdf(pdf: Data) -> AnyPublisher<ChatPdfRef, ChatPdfError> {
        // TODO: Implement actual API
        return Self.getDelayedResponse(response: ChatPdfRef(sourceId: "test_source_id"))
    }
    
    func generateText(ref: ChatPdfRef, prompt: String) -> AnyPublisher<ChatPdfMessage, ChatPdfError> {
        // TODO: Implement actual API
        return Self.getDelayedResponse(response: ChatPdfMessage(role: .assistant, type: .text, content: "test_message"))
    }
    
    private static  func getDelayedResponse<T>(response: T) -> AnyPublisher<T, ChatPdfError> {
        return Just.withErrorType((), ChatPdfError.self)
            .delay(for: RunLoop.SchedulerTimeType.Stride(K.Test.ChatPdfNetworkStubsDelay), scheduler: RunLoop.main)
            .flatMap { Just.withErrorType(response, ChatPdfError.self) }
            .eraseToAnyPublisher()
    }
}
