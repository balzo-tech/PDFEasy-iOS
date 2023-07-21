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

extension ChatPdfMessage: Decodable {
    private enum CodingKeys: CodingKey {
        case content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decode(String.self, forKey: .content)
        self.type = .text
        self.role = .assistant
    }
}
