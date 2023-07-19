//
//  ChatPdfManagerImpl.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation

class ChatPdfManagerImpl: ChatPdfManager {
    
    private let apiKey: String
    
    init() {
        self.apiKey = ProjectInfo.chatPdfApiKey
    }
    
    func sendPdf(pdf: Data) async throws -> String {
        return ""
    }
    
    func generateText(prompt: String) async throws -> String {
        return ""
//        return try await withCheckedThrowingContinuation({ continuation in
//            client.sendCompletion(with: prompt, maxTokens: 500) { result in
//                switch result {
//                case .success(let model):
//                    let output = model.choices.first?.text ?? ""
//                    continuation.resume(returning: output)
//                case .failure(let error):
//                    continuation.resume(throwing: error)
//                }
//            }
//        })
    }
}
