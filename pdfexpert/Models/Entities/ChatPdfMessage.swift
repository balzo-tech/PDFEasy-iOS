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

struct ChatPdfMessage {
    let role: ChatPdfMessageRole
    let type: ChatPdfMessageType
    let content: String
}
