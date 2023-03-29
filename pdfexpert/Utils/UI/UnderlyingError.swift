//
//  UnderlyingError.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation

protocol UnderlyingError: Error {
    static func getUnknownError() -> Self
    static func getUnderlyingError(errorDescription: String) -> Self
    static func convertUnderlyingError(fromError error: Error) -> Self?
}

extension Error {
    static func getSelfError(forError error: Error) -> Self? {
        return error as? Self
    }
}

extension UnderlyingError {
    static func convertError(fromError error: Error) -> Self {
        return Self.getSelfError(forError: error) ?? Self.convertUnderlyingError(fromError: error) ?? Self.getUnknownError()
    }
    
    static func convertUnderlyingError(fromError error: Error) -> Self? {
        return Self.getUnderlyingError(errorDescription: error.localizedDescription)
    }
}
