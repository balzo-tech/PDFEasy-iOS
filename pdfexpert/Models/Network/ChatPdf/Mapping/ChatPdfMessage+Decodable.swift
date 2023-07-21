//
//  ChatPdfMessage+Decodable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/07/23.
//

import Foundation

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
