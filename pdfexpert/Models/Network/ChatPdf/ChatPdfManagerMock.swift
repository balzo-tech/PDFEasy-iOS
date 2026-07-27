//
//  ChatPdfManagerMock.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 02/03/23.
//
//  Standalone mock (no network, no third-party dependency) used by SwiftUI
//  previews and, in DEBUG, when `K.Test.ChatPdf.UseMock` is enabled. It returns
//  canned responses, optionally after `K.Test.ChatPdf.NetworkStubsDelay` seconds
//  so loading states can be exercised.
//

import Foundation
import Combine

class ChatPdfManagerMock: ChatPdfManager {

    private let stubDelay: TimeInterval = K.Test.ChatPdf.NetworkStubsDelay

    func sendPdf(pdf: Data) -> AnyPublisher<ChatPdfRef, ChatPdfError> {
        self.stubbed(ChatPdfRef(sourceId: UUID().uuidString))
    }

    func getSetupData(ref: ChatPdfRef) -> AnyPublisher<ChatPdfSetupData, ChatPdfError> {
        self.stubbed(ChatPdfSetupData(summary: "This is a mock summary of your document.",
                                      suggestedQuestions: [
                                        "What is this document about?",
                                        "Who is the author?",
                                        "Can you summarize the key points?"
                                      ]))
    }

    func generateText(ref: ChatPdfRef, prompt: String) -> AnyPublisher<ChatPdfMessage, ChatPdfError> {
        self.stubbed(ChatPdfMessage(role: .assistant, type: .text, content: "This is a mock answer to: \"\(prompt)\""))
    }

    func deletePdf(ref: ChatPdfRef) {
        // No-op for the mock.
    }

    private func stubbed<T>(_ value: T) -> AnyPublisher<T, ChatPdfError> {
        let publisher = Just(value).setFailureType(to: ChatPdfError.self)
        if self.stubDelay > 0.0 {
            return publisher
                .delay(for: .seconds(self.stubDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        return publisher.eraseToAnyPublisher()
    }
}
