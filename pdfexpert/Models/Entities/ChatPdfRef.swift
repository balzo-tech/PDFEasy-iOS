//
//  ChatPdfRef.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 20/07/23.
//

import Foundation

struct ChatPdfRef: Hashable, Identifiable {
    
    var id: Self { return self }
    
    let sourceId: String
}

extension ChatPdfRef: Decodable {
    private enum CodingKeys: CodingKey {
        case sourceId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sourceId = try container.decode(String.self, forKey: .sourceId)
    }
}
