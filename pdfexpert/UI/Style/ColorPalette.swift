//
//  ColorPalette.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit

typealias ColorMap = [ColorType: UIColor]

enum ColorType: String, CaseIterable, CodingKey {
    case primary = "primary_color_start"
    case secondary = "secondary_color"
    case tertiary = "tertiary_color_start"
    case fourth = "fourth_color"
    case primaryText = "primary_text_color"
    case secondaryText = "secondary_text_color"
    case tertiaryText = "tertiary_text_color"
    case fourthText = "fourth_text_color"
    case primaryMenu = "primary_menu_color"
    case secondaryMenu = "secondary_menu_color"
    case active = "active_color"
    case inactive = "deactive_color"
    case gradientPrimaryEnd = "primary_color_end"
    case gradientTertiaryEnd = "tertiary_color_end"
    
    var defaultColor: UIColor {
        switch self {
        case .primary: return UIColor(hexRGB: 0x121315)
        case .secondary: return UIColor(hexRGB: 0x232426)
        case .tertiary: return UIColor(hexRGB: 0x34CBD9)
        case .fourth: return UIColor(hexRGB: 0xF5F5F5)
        case .primaryText: return UIColor(hexRGB: 0xFFFFFF)
        case .secondaryText: return UIColor(hexRGB: 0x00C3F6)
        case .tertiaryText: return UIColor(hexRGB: 0xB9B9B9)
        case .fourthText: return UIColor(hexRGB: 0xFFC700)
        case .primaryMenu: return UIColor(hexRGB: 0x140F26)
        case .secondaryMenu: return UIColor(hexRGB: 0xC4C4C4)
        case .active: return UIColor(hexRGB: 0x54C788)
        case .inactive: return UIColor(hexRGB: 0xDFDFDF)
        case .gradientPrimaryEnd: return UIColor(hexRGB: 0x0B99AE)
        case .gradientTertiaryEnd: return UIColor(hexRGB: 0x25B8C9)
        }
    }
}

class ColorPalette {
    
    private static var colorMap: ColorMap = [:]
    
    static func initialize(withColorMap colorMap: ColorMap) {
        self.colorMap = colorMap
    }
    
    static func color(withType type: ColorType) -> UIColor {
        return self.colorMap[type] ?? type.defaultColor
    }
    
    // Fixed colors
    static var shadowColor = UIColor(hexRGBA: 0x30374029)
    static var overlayColor = UIColor(hexRGBA: 0x30374080)
    
    static var errorPrimaryColor = UIColor(hexRGB: 0x303740)
    static var errorSecondaryColor = UIColor(hexRGB: 0xFFFFFF)
}
