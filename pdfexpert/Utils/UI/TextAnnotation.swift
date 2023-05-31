//
//  TextAnnotation.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 30/05/23.
//

import Foundation
import PDFKit

class TextAnnotation: PDFAnnotation {
    var text: String
    
    init(with text: String,
         forBounds bounds: CGRect,
         textColor: UIColor,
         fontSize: CGFloat,
         fontFamilyName: String?,
         withProperties properties: [AnyHashable : Any]?) {
        self.text = text
        super.init(bounds: bounds, forType: PDFAnnotationSubtype.freeText,  withProperties: properties)
        self.fontColor = textColor
        self.color = .clear
        if let fontFamilyName = fontFamilyName {
            self.font = UIFont(name: fontFamilyName, size: fontSize)
        } else {
            self.font = UIFont(name: "Arial", size: fontSize)//UIFont(name: "", size: fontSize)//.systemFont(ofSize: fontSize)
        }
        self.alignment = .center
        self.contents = text
    }
    
//    init(with text: String, forBounds bounds: CGRect, textColor: UIColor, fontFamilyName: String?, withProperties properties: [AnyHashable : Any]?) {
//        self.text = text
//        super.init(bounds: bounds, forType: PDFAnnotationSubtype.widget,  withProperties: properties)
//        self.widgetFieldType = .text
//        self.widgetStringValue = text
//        self.fontColor = textColor
//        self.backgroundColor = .blue
//        self.color = .red
//        if let fontFamilyName = fontFamilyName {
//            self.font = UIFont(name: fontFamilyName, size: 20)
//        } else {
//            self.font = .systemFont(ofSize: 20)
//        }
//        self.alignment = .center
////        self.contents = text
//    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
