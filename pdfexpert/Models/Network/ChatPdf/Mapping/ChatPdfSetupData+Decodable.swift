//
//  ChatPdfSetupData+Decodable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 10/08/23.
//

import Foundation

extension ChatPdfSetupData: Decodable {
    enum CodingKeys: String, CodingKey {
        case summary
        case suggestedQuestions = "suggested_questions"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.suggestedQuestions = (try? container.decode([String].self, forKey: .suggestedQuestions)) ?? []
        if self.summary.isEmpty {
            throw DecodingError.dataCorruptedError(forKey: .summary, in: container, debugDescription: "Summary cannot be empty")
        }
    }
}
