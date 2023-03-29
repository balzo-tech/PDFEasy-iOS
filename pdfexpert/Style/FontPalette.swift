//
//  FontPalette.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import Foundation
import SwiftUI

class FontPalette {
    static func fontBlack(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-Black", size: size)
    }
    static func fontBlackItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-BlackItalic", size: size)
    }
    static func fontBold(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-Bold", size: size)
    }
    static func fontBoldItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-BoldItalic", size: size)
    }
    static func fontExtraBold(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-ExtraBold", size: size)
    }
    static func fontExtraBoldItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-ExtraBoldItalic", size: size)
    }
    static func fontExtraLight(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-ExtraLight", size: size)
    }
    static func fontExtraLightItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-ExtraLightItalic", size: size)
    }
    static func fontItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-Italic", size: size)
    }
    static func fontLight(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-Light", size: size)
    }
    static func fontLightItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-LightItalic", size: size)
    }
    static func fontMedium(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-Medium", size: size)
    }
    static func fontMediumItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-MediumItalic", size: size)
    }
    static func fontRegular(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-Regular", size: size)
    }
    static func fontSemiBold(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-SemiBold", size: size)
    }
    static func fontSemiBoldItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-SemiBoldItalic", size: size)
    }
    static func fontThin(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-Thin", size: size)
    }
    static func fontThinItalic(withSize size: CGFloat) -> Font {
        return Font.custom("Montserrat-ThinItalic", size: size)
    }
    
    static func uiFontBlack(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-Black", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontBlackItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-BlackItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontBold(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-Bold", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontBoldItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-BoldItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontExtraBold(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-ExtraBold", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontExtraBoldItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-ExtraBoldItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontExtraLight(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-ExtraLight", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontExtraLightItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-ExtraLightItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-Italic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontLight(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-Light", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontLightItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-LightItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontMedium(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-Medium", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontMediumItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-MediumItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontRegular(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-Regular", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontSemiBold(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-SemiBold", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontSemiBoldItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-SemiBoldItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontThin(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-Thin", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
    static func uiFontThinItalic(withSize size: CGFloat) -> UIFont {
        return UIFont(name: "Montserrat-ThinItalic", size: size) ?? UIFont.italicSystemFont(ofSize: size)
    }
}
