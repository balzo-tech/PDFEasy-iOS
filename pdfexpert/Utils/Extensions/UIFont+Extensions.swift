//
//  UIFont+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 01/06/23.
//

import Foundation
import UIKit

extension UIFont {
    static func font(named fontName: String,
                     fitting text: String,
                     into targetSize: CGSize,
                     with attributes: [NSAttributedString.Key: Any],
                     options: NSStringDrawingOptions) -> UIFont {
        var attributes = attributes
        let fontSize = targetSize.height

        attributes[.font] = UIFont(name: fontName, size: fontSize)
        let size = text.boundingRect(with: CGSize(width: .greatestFiniteMagnitude, height: fontSize),
                                     options: options,
                                     attributes: attributes,
                                     context: nil).size

        let heightSize = targetSize.height / (size.height / fontSize)
        let widthSize = targetSize.width / (size.width / fontSize)
        let minSize = min(heightSize, widthSize)
        
        return UIFont(name: fontName, size: minSize) ?? .systemFont(ofSize: minSize)
    }
}
