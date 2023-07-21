//
//  ChatPdfManagerMock.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import Combine

class ChatPdfManagerMock: ChatPdfManager {
    
    private let texts = ["Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                         "Hi!",
                         "I guess you guys aren't ready for that, yet. But your kids are gonna love it"]
    
    private var index: Int = 0
    
    func sendPdf(pdf: Data) -> AnyPublisher<ChatPdfRef, ChatPdfError> {
        return Self.getDelayedResponse(response: ChatPdfRef(sourceId: "test_source_id"))
    }
    
    func generateText(ref: ChatPdfRef, prompt: String) -> AnyPublisher<ChatPdfMessage, ChatPdfError> {
        let text = self.texts[self.index % self.texts.count]
        self.index += 1
        return Self.getDelayedResponse(response: ChatPdfMessage(role: .assistant, type: .text, content: text))
    }
    
    private static  func getDelayedResponse<T>(response: T) -> AnyPublisher<T, ChatPdfError> {
        return Just.withErrorType((), ChatPdfError.self)
            .delay(for: RunLoop.SchedulerTimeType.Stride(K.Test.ChatPdf.NetworkStubsDelay), scheduler: RunLoop.main)
            .flatMap { Just.withErrorType(response, ChatPdfError.self) }
            .eraseToAnyPublisher()
    }
}
