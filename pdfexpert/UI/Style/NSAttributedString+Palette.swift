//
//  NSAttributedString+Palette.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import UIKit

extension NSAttributedString {
    
    class func create(withText text: String,
                      attributedTextStyle: AttributedTextStyle) -> NSAttributedString {
        let textColor = ColorPalette.color(withType: attributedTextStyle.colorType).applyAlpha(attributedTextStyle.alpha)
        return NSAttributedString.create(withText: text,
                                         fontStyle: attributedTextStyle.fontStyle,
                                         color: textColor,
                                         textAlignment: attributedTextStyle.textAlignment,
                                         underlined: attributedTextStyle.underlined)
    }
    
    class func create(withText text: String,
                      fontStyle: FontStyle,
                      colorType: ColorType,
                      textAlignment: NSTextAlignment = .center,
                      underlined: Bool = false) -> NSAttributedString {
        return NSAttributedString.create(withText: text,
                                         fontStyle: fontStyle,
                                         color: ColorPalette.color(withType: colorType),
                                         textAlignment: textAlignment,
                                         underlined: underlined)
    }
    
    class func create(withText text: String,
                      fontStyle: FontStyle,
                      color: UIColor,
                      textAlignment: NSTextAlignment = .center,
                      underlined: Bool = false) -> NSAttributedString {
        let fontStyleData = FontPalette.fontStyleData(forStyle: fontStyle)
        return NSAttributedString.create(withText: text,
                                         font: fontStyleData.font,
                                         lineSpacing: fontStyleData.lineSpacing,
                                         uppercase: fontStyleData.uppercase,
                                         color: color,
                                         textAlignment: textAlignment,
                                         underlined: underlined)
    }
}
