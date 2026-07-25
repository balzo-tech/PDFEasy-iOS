//
//  FontPalette.swift
//  PdfExpert
//
//  Typography is the system face (SF) driven by Dynamic Type: every font here
//  resolves to a text style, so it scales with the user's content-size setting
//  and picks up the optical sizing SF applies at each size.
//
//  The app used to ship Poppins at fixed point sizes. The `font*(withSize:)`
//  entry points are kept as a shim — they map the requested size onto the
//  closest text style — so the screens that have not been reworked keep
//  compiling while still becoming accessible.
//

import Foundation
import SwiftUI
import UIKit

class FontPalette {

    /// Maps a legacy point size onto the text style that matches it at the
    /// default content size, so the result scales with Dynamic Type.
    fileprivate static func textStyle(forSize size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2
        case ..<12.5: return .caption
        case ..<13.5: return .footnote
        case ..<15.5: return .subheadline
        case ..<17.5: return .body
        case ..<19.5: return .title3
        case ..<23.5: return .title2
        case ..<29.5: return .title
        default: return .largeTitle
        }
    }

    fileprivate static func uiTextStyle(forSize size: CGFloat) -> UIFont.TextStyle {
        switch Self.textStyle(forSize: size) {
        case .caption2: return .caption2
        case .caption: return .caption1
        case .footnote: return .footnote
        case .subheadline: return .subheadline
        case .body: return .body
        case .title3: return .title3
        case .title2: return .title2
        case .title: return .title1
        case .largeTitle: return .largeTitle
        default: return .body
        }
    }

    static func font(withSize size: CGFloat, weight: Font.Weight) -> Font {
        Font.system(Self.textStyle(forSize: size), weight: weight)
    }

    static func uiFont(withSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let style = Self.uiTextStyle(forSize: size)
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        let base = UIFont.systemFont(ofSize: descriptor.pointSize, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    static func uiFont(withSize size: CGFloat, weight: UIFont.Weight, italic: Bool) -> UIFont {
        let font = Self.uiFont(withSize: size, weight: weight)
        guard italic, let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    // MARK: - Legacy weight-named entry points

    static func fontBlack(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .black) }
    static func fontBlackItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .black).italic() }
    static func fontBold(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .bold) }
    static func fontBoldItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .bold).italic() }
    static func fontExtraBold(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .heavy) }
    static func fontExtraBoldItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .heavy).italic() }
    static func fontExtraLight(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .ultraLight) }
    static func fontExtraLightItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .ultraLight).italic() }
    static func fontItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .regular).italic() }
    static func fontLight(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .light) }
    static func fontLightItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .light).italic() }
    static func fontMedium(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .medium) }
    static func fontMediumItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .medium).italic() }
    static func fontRegular(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .regular) }
    static func fontSemiBold(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .semibold) }
    static func fontSemiBoldItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .semibold).italic() }
    static func fontThin(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .thin) }
    static func fontThinItalic(withSize size: CGFloat) -> Font { Self.font(withSize: size, weight: .thin).italic() }

    static func uiFontBlack(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .black) }
    static func uiFontBlackItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .black, italic: true) }
    static func uiFontBold(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .bold) }
    static func uiFontBoldItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .bold, italic: true) }
    static func uiFontExtraBold(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .heavy) }
    static func uiFontExtraBoldItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .heavy, italic: true) }
    static func uiFontExtraLight(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .ultraLight) }
    static func uiFontExtraLightItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .ultraLight, italic: true) }
    static func uiFontItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .regular, italic: true) }
    static func uiFontLight(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .light) }
    static func uiFontLightItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .light, italic: true) }
    static func uiFontMedium(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .medium) }
    static func uiFontMediumItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .medium, italic: true) }
    static func uiFontRegular(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .regular) }
    static func uiFontSemiBold(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .semibold) }
    static func uiFontSemiBoldItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .semibold, italic: true) }
    static func uiFontThin(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .thin) }
    static func uiFontThinItalic(withSize size: CGFloat) -> UIFont { Self.uiFont(withSize: size, weight: .thin, italic: true) }
}

/// Semantic roles used across the app. Each one is a system text style, so the
/// whole UI scales together and stays legible at accessibility sizes.
enum FontCategory {
    case largeTitle
    case title1
    case title2
    case title3
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
        case .largeTitle: return .system(.largeTitle, weight: .bold)
        case .title1: return .system(.title, weight: .bold)
        case .title2: return .system(.title2, weight: .semibold)
        case .title3: return .system(.title3, weight: .semibold)
        case .button: return .system(.headline, weight: .semibold)
        case .headline: return .system(.headline, weight: .semibold)
        case .body1: return .system(.body)
        case .body2: return .system(.subheadline)
        case .body3: return .system(.body, weight: .medium)
        case .linkText: return .system(.subheadline, weight: .medium)
        case .callout: return .system(.caption, weight: .medium)
        case .caption1: return .system(.caption)
        case .caption2: return .system(.caption2)
        }
    }
}

extension View {
    func font(forCategory category: FontCategory) -> some View {
        self.font(category.font)
    }
}
