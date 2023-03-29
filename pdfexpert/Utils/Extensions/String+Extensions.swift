//
//  String+Extensions.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 06/03/23.
//

import Foundation

extension String {
    
    public var nilIfEmpty: String? {
        return self.isEmpty ? nil : self
    }
    
    public func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    public mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}
