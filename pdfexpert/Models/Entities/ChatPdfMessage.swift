//
//  ChatPdfMessage.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 20/07/23.
//

import Foundation

enum ChatPdfMessageRole {
    case user
    case assistant
}

enum ChatPdfMessageType {
    case text
    case indicator
}

struct ChatPdfMessage: Hashable {
    let role: ChatPdfMessageRole
    let type: ChatPdfMessageType
    let content: String
    let suggestedQuestions: [String]
}

extension ChatPdfMessage {
    init(role: ChatPdfMessageRole, type: ChatPdfMessageType, content: String) {
        self.role = role
        self.type = type
        self.content = content
        self.suggestedQuestions = []
    }
}
