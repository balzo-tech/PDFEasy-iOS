//
//  ColorPalette.swift
//  PdfExpert
//
//  The app's semantic color layer. Every token is defined in code as a dynamic
//  color with a light and a dark value, so the UI follows the system appearance
//  (the app used to be locked to dark via INFOPLIST_KEY_UIUserInterfaceStyle).
//
//  The historical token names (primaryBG, thirdText, …) are kept as aliases so
//  the existing screens keep compiling; new code should prefer the semantic
//  names below (background, surface, textPrimary, accent, …).
//

import Foundation
import SwiftUI
import UIKit

extension Color {

    /// Builds a color that resolves differently in light and dark appearance.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

class ColorPalette {

    // MARK: - Surfaces

    /// App-level background, behind everything.
    static let background = Color(light: "F3F5F9", dark: "0C0E13")
    /// Cards, rows, grouped content sitting on `background`.
    static let surface = Color(light: "FFFFFF", dark: "1A1D24")
    /// A surface raised above `surface` (nested cards, selected states).
    static let surfaceElevated = Color(light: "FFFFFF", dark: "242832")
    /// Hairlines and dividers.
    static let separator = Color(light: "DFE3EB", dark: "2C303A")

    // MARK: - Content

    static let textPrimary = Color(light: "0E1117", dark: "F5F7FA")
    static let textSecondary = Color(light: "5B6472", dark: "A6AEBC")
    static let textTertiary = Color(light: "8C94A3", dark: "6C7482")

    // MARK: - Brand

    /// Primary brand tint: buttons, selection, active tab.
    static let accent = Color(light: "0A63E8", dark: "4D9DFF")
    /// The second stop of the brand gradient.
    static let accentSecondary = Color(light: "00A6E0", dark: "38D0FF")
    /// Premium / paid features.
    static let premium = Color(light: "C98800", dark: "FFC94A")

    // MARK: - Status

    static let danger = Color(light: "D62B2B", dark: "FF6B6B")
    static let success = Color(light: "17875A", dark: "34D399")

    // MARK: - Signature sheet
    //
    // The signature pad is a sheet of paper you sign with black ink, and what is
    // drawn there ends up stamped on the document. It must not follow the system
    // appearance: these three are fixed in both themes.

    static let signatureSheet = Color(hex: "FFFFFF")
    static let signatureInk = Color(hex: "10131A")
    static let signatureInkSecondary = Color(hex: "6B7280")

    // MARK: - Tool categories
    //
    // Each tool family carries its own hue, the way system utilities tint their
    // symbols. Used by the tool tiles and by the editor action menu.

    static let categoryCreate = Color(light: "2F6BFF", dark: "5E9BFF")
    static let categoryOrganize = Color(light: "7A5AF8", dark: "A78BFA")
    static let categoryEdit = Color(light: "E0700F", dark: "FF9F45")
    static let categoryProtect = Color(light: "17875A", dark: "34D399")
    static let categoryExport = Color(light: "0E8FA8", dark: "38BEC9")
    static let categoryRead = Color(light: "4F46E5", dark: "8B93FF")
    static let categoryAi = Color(light: "C6339B", dark: "F472B6")

    // MARK: - Legacy aliases
    //
    // Kept so the screens that have not been reworked yet keep their meaning.

    static let primary = accent
    static let primaryBG = background
    static let secondaryBG = surface
    static let primaryText = textPrimary
    static let secondaryText = accent
    static let thirdText = textSecondary
    static let fourthText = textTertiary
    static let extra = premium
    static let buttonGradientStart = accent
    static let buttonGradientEnd = accentSecondary
}
