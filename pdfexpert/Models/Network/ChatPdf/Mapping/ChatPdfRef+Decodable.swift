//
//  ChatPdfRef+Decodable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/07/23.
//

import Foundation

extension ChatPdfRef: Decodable {
    private enum CodingKeys: CodingKey {
        case sourceId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sourceId = try container.decode(String.self, forKey: .sourceId)
    }
}
