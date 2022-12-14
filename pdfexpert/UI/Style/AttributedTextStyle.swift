//
//  AttributedTextStyle.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import Foundation
import UIKit

struct AttributedTextStyle {
    let fontStyle: FontStyle
    let colorType: ColorType
    let textAlignment: NSTextAlignment
    let underlined: Bool
    let alpha: CGFloat
    
    init(fontStyle: FontStyle,
         colorType: ColorType,
         textAlignment: NSTextAlignment = .center,
         underlined: Bool = false,
         alpha: CGFloat = 1.0) {
        self.fontStyle = fontStyle
        self.colorType = colorType
        self.textAlignment = textAlignment
        self.underlined = underlined
        self.alpha = alpha
    }
}
