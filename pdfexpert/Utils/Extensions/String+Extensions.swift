//
//  String+Extensions.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 06/03/23.
//

import Foundation
import UIKit

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
    
    public func boundingRect(font: UIFont?,
                             with attributes: [NSAttributedString.Key: Any],
                             options: NSStringDrawingOptions) -> CGRect {
        var attributes = attributes
        attributes[.font] = font
        return self.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                              height: CGFloat.greatestFiniteMagnitude),
                                 options: options,
                                 attributes: attributes,
                                 context: nil)
    }
}
