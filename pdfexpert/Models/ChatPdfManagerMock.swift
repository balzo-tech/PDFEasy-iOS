//
//  ChatPdfManagerMock.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation

class ChatPdfManagerMock: ChatPdfManager {
    
    private let texts = ["Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                         "Hi!",
                         "I guess you guys aren't ready for that, yet. But your kids are gonna love it"]
    
    private var index: Int = 0
    
    func sendPdf(pdf: Data) async throws -> String {
        return ""
    }
    
    func generateText(prompt: String) async throws -> String {
        try await Task.sleep(until: .now + .seconds(1), clock: .continuous)
        let text = self.texts[self.index % self.texts.count]
        self.index += 1
        return text
    }
}
