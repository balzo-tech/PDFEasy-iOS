//
//  SharedLocalizedError.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 07/03/23.
//

import Foundation

enum SharedLocalizedError: LocalizedError {
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return "Internal Error. Please try again later"
        }
    }
}
