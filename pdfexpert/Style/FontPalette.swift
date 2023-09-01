//
//  FontPalette.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import Foundation
import SwiftUI

class FontPalette {
    
    private static let fontFamily: String = "Poppins"
    
    static func fontBlack(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-Black", size: size)
    }
    static func fontBlackItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-BlackItalic", size: size)
    }
    static func fontBold(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-Bold", size: size)
    }
    static func fontBoldItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-BoldItalic", size: size)
    }
    static func fontExtraBold(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-ExtraBold", size: size)
    }
    static func fontExtraBoldItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-ExtraBoldItalic", size: size)
    }
    static func fontExtraLight(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-ExtraLight", size: size)
    }
    static func fontExtraLightItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-ExtraLightItalic", size: size)
    }
    static func fontItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-Italic", size: size)
    }
    static func fontLight(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-Light", size: size)
    }
    static func fontLightItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-LightItalic", size: size)
    }
    static func fontMedium(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-Medium", size: size)
    }
    static func fontMediumItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-MediumItalic", size: size)
    }
    static func fontRegular(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-Regular", size: size)
    }
    static func fontSemiBold(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-SemiBold", size: size)
    }
    static func fontSemiBoldItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-SemiBoldItalic", size: size)
    }
    static func fontThin(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-Thin", size: size)
    }
    static func fontThinItalic(withSize size: CGFloat) -> Font {
        return Font.custom("\(Self.fontFamily)-ThinItalic", size: size)
    }
    
    static func uiFontBlack(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-Black", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }
    static func uiFontBlackItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-BlackItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontBold(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }
    static func uiFontBoldItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-BoldItalic", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }
    static func uiFontExtraBold(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-ExtraBold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }
    static func uiFontExtraBoldItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-ExtraBoldItalic", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }
    static func uiFontExtraLight(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-ExtraLight", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    static func uiFontExtraLightItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-ExtraLightItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-Italic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontLight(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-Light", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    static func uiFontLightItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-LightItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontMedium(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-Medium", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    static func uiFontMediumItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-MediumItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontRegular(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-Regular", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    static func uiFontSemiBold(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-SemiBold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }
    static func uiFontSemiBoldItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-SemiBoldItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontThin(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-Thin", size: size) ?? UIFont.systemFont(ofSize: size)
    }
    static func uiFontThinItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "\(Self.fontFamily)-ThinItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
}

enum FontCategory {
    case largeTitle
    case title1
    case title2
    case button
    case headline
    case body1
    case body2
    case body3
    case linkText
    case callout
    case caption1
    case caption2
    
    var font: Font {
        switch self {
        case .largeTitle: return FontPalette.fontMedium(withSize: 32)
        case .title1: return FontPalette.fontMedium(withSize: 24)
        case .title2: return FontPalette.fontMedium(withSize: 22)
        case .button: return FontPalette.fontMedium(withSize: 18)
        case .headline: return FontPalette.fontMedium(withSize: 18)
        case .body1: return FontPalette.fontRegular(withSize: 16)
        case .body2: return FontPalette.fontRegular(withSize: 14)
        case .body3: return FontPalette.fontMedium(withSize: 16)
        case .linkText: return FontPalette.fontRegular(withSize: 14)
        case .callout: return FontPalette.fontMedium(withSize: 12)
        case .caption1: return FontPalette.fontRegular(withSize: 12)
        case .caption2: return FontPalette.fontRegular(withSize: 10)
        }
    }
}

extension View {
    func font(forCategory category: FontCategory) -> some View {
        self.font(category.font)
    }
}
