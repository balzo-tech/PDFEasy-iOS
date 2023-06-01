//
//  TextAnnotation.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 30/05/23.
//

import Foundation
import PDFKit

class TextAnnotation: PDFAnnotation {
    
    var text: String { self.contents ?? "" }
    
    init(with text: String,
         forBounds bounds: CGRect,
         textColor: UIColor,
         fontName: String,
         withProperties properties: [AnyHashable : Any]?) {
        let font = UIFont.font(named: fontName, fitting: text, into: bounds.size, with: [:], options: [])
        let encodedBounds = bounds.encode(forText: text, withFont: font)
        super.init(bounds: encodedBounds, forType: PDFAnnotationSubtype.freeText,  withProperties: properties)
        self.fontColor = textColor
        self.color = .clear
        self.font = font
        self.alignment = .center
        self.contents = text
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PDFAnnotation {
    
    var verticalCenteredTextBounds: CGRect {
        self.bounds.decode(forText: self.contents ?? "", withFont: self.font)
    }
}

fileprivate extension CGRect {
    
    static var safetyMargin: CGFloat { 0.0 }
    
    func encode(forText text: String, withFont font: UIFont?) -> CGRect {
        let offsetY = -self.size.height / 2 + text.boundingRect(font: font, with: [:], options: []).size.height / 2
//        print("TextAnnotation: encoding offset Y: \(offsetY), for Text: \(text), fontSize: \(font!.pointSize)")
        return self.offsetBy(dx: 0, dy: offsetY)
            .inset(by: UIEdgeInsets(top: -Self.safetyMargin, left: -Self.safetyMargin, bottom: -Self.safetyMargin, right: -Self.safetyMargin))
    }
    
    func decode(forText text: String, withFont font: UIFont?) -> CGRect {
        let offsetY = self.size.height / 2 - text.boundingRect(font: font, with: [:], options: []).size.height / 2
//        print("TextAnnotation: decoding offset Y: \(offsetY), for Text: \(text), fontSize: \(font!.pointSize)")
        return self.offsetBy(dx: 0, dy: offsetY)
            .inset(by: UIEdgeInsets(top: -Self.safetyMargin, left: -Self.safetyMargin, bottom: -Self.safetyMargin, right: -Self.safetyMargin))
    }
}
