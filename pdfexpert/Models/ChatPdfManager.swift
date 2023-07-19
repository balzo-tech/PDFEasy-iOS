//
//  ChatPdfManager.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import Factory

protocol ChatPdfManager {
    func sendPdf(pdf: Data) async throws -> String
    func generateText(prompt: String) async throws -> String
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
