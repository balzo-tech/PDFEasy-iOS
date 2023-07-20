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

enum SharedUnderlyingError: LocalizedError, UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        }
    }
}

enum PdfEditableError: LocalizedError, UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    case wrongPassword
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        case .wrongPassword: return "Wrong Password"
        }
    }
}
