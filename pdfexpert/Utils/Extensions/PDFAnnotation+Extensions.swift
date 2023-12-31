//
//  PDFAnnotation+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 30/05/23.
//

import Foundation
import PDFKit

private enum PDFCustomKey: String {
    case annotationType = "type"
}

private enum PDFAnnotationTypeValue: String {
    case signature = "signature"
}

extension PDFAnnotation {
    
    var text: String { self.contents ?? "" }
    
    var isTextAnnotation: Bool {
        guard let subType = self.annotationKeyValues[PDFAnnotationKey.subtype] as? PDFAnnotationSubtype, subType == PDFAnnotationSubtype.freeText else {
            return false
        }
        return true
    }
    
    var isWidgetAnnotation: Bool {
        guard let subType = self.annotationKeyValues[PDFAnnotationKey.subtype] as? PDFAnnotationSubtype, subType == PDFAnnotationSubtype.widget else {
            return false
        }
        return true
    }
    
    var isSignatureAnnotation: Bool {
        guard let subType = self.annotationKeyValues[PDFAnnotationKey.subtype] as? PDFAnnotationSubtype,
              subType == PDFAnnotationSubtype.stamp,
              self.annotationKeyValues.getCustomPdfValue(forKey: PDFCustomKey.annotationType.rawValue) == PDFAnnotationTypeValue.signature.rawValue else {
            return false
        }
        return true
    }
    
    var image: UIImage {
        let renderer = UIGraphicsImageRenderer(size: self.bounds.size)
        return renderer.image { ctx in
            
            ctx.cgContext.translateBy(x: -self.bounds.origin.x, y: self.bounds.origin.y)
            // Flip the context vertically because the Core Graphics coordinate system starts from the bottom.
            ctx.cgContext.translateBy(x: 0, y: self.bounds.size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            
            self.draw(with: .mediaBox, in: ctx.cgContext)
        }
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
    
    static func createSignature(with image: UIImage,
         forBounds bounds: CGRect) -> PDFAnnotation {
        var properties: [AnyHashable: Any] = [:]
        properties.addCustomPdfValue(PDFAnnotationTypeValue.signature.rawValue, forKey: PDFCustomKey.annotationType.rawValue)
        let annotation = ImageStampAnnotation(with: image, forBounds: bounds, withProperties: properties)
        return annotation
    }
}

fileprivate extension CGRect {
    
    static var safetyMargin: CGFloat { 10.0 }
    
    func encode(forText text: String, withFont font: UIFont?) -> CGRect {
        let size = text.boundingRect(font: font, with: [:], options: []).size
        let center = CGPoint(x: self.origin.x + self.size.width / 2, y: self.origin.y + self.size.height / 2)
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        return CGRect(origin: origin, size: size)
            .inset(by: UIEdgeInsets(top: -Self.safetyMargin,
                                    left: -Self.safetyMargin,
                                    bottom: -Self.safetyMargin,
                                    right: -Self.safetyMargin))
    }
    
    func decode(forText text: String, withFont font: UIFont?) -> CGRect {
        return self
            .inset(by: UIEdgeInsets(top: Self.safetyMargin,
                                    left: Self.safetyMargin,
                                    bottom: Self.safetyMargin,
                                    right: Self.safetyMargin))
    }
}

fileprivate extension Dictionary where Key == AnyHashable, Value == Any {
    
    private static var keyPrefix: String { "PdfExpert" }
    
    mutating func addCustomPdfValue(_ value: Any, forKey key: AnyHashable) {
        self["\(Self.keyPrefix)_\(key)"] = value
    }
    
    func getCustomPdfValue<T>(forKey key: AnyHashable) -> T? {
        return self["/\(Self.keyPrefix)_\(key)"] as? T
    }
}
