//
//  PDFAnnotation+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 30/05/23.
//

import Foundation
import PDFKit

extension PDFAnnotation {
    
    var text: String { self.contents ?? "" }
    
    var isTextAnnotation: Bool {
        guard let subType = self.annotationKeyValues[PDFAnnotationKey.subtype] as? PDFAnnotationSubtype, subType == PDFAnnotationSubtype.freeText else {
            return false
        }
        return true
    }
    
    var verticalCenteredTextBounds: CGRect {
        self.bounds.decode(forText: self.contents ?? "", withFont: self.font)
    }
    
    static func create(with text: String,
         forBounds bounds: CGRect,
         textColor: UIColor,
         fontName: String,
         withProperties properties: [AnyHashable : Any]?) -> PDFAnnotation {
        let font = UIFont.font(named: fontName, fitting: text, into: bounds.size, with: [:], options: [])
        let encodedBounds = bounds.encode(forText: text, withFont: font)
        let annotation = PDFAnnotation(bounds: encodedBounds, forType: PDFAnnotationSubtype.freeText,  withProperties: properties)
        annotation.fontColor = textColor
        annotation.color = .clear
        annotation.font = font
        annotation.alignment = .center
        annotation.contents = text
        return annotation
    }
}

fileprivate extension CGRect {
    
    static var safetyMargin: CGFloat { 0.0 }
    
    func encode(forText text: String, withFont font: UIFont?) -> CGRect {
        let offsetY = -self.size.height / 2 + text.boundingRect(font: font, with: [:], options: []).size.height / 2
        return self.offsetBy(dx: 0, dy: offsetY)
            .inset(by: UIEdgeInsets(top: -Self.safetyMargin, left: -Self.safetyMargin, bottom: -Self.safetyMargin, right: -Self.safetyMargin))
    }
    
    func decode(forText text: String, withFont font: UIFont?) -> CGRect {
        let offsetY = self.size.height / 2 - text.boundingRect(font: font, with: [:], options: []).size.height / 2
        return self.offsetBy(dx: 0, dy: offsetY)
            .inset(by: UIEdgeInsets(top: -Self.safetyMargin, left: -Self.safetyMargin, bottom: -Self.safetyMargin, right: -Self.safetyMargin))
    }
}
