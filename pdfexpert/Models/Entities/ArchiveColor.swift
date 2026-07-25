//
//  ArchiveColor.swift
//  PdfExpert
//
//  The palette a user can pick from when creating a folder or a tag. Stored as
//  an index rather than a hex string, so the actual hues stay a design decision
//  and can be retuned without touching the saved data (or the CloudKit records).
//

import Foundation
import SwiftUI

enum ArchiveColor: Int32, CaseIterable, Identifiable, Hashable {

    case blue, purple, pink, red, orange, yellow, green, teal, gray

    var id: Int32 { self.rawValue }

    /// Falls back to `.blue` for a value written by a future version of the app
    /// (the record can arrive from iCloud before the update does).
    static func from(rawValue: Int32) -> ArchiveColor {
        ArchiveColor(rawValue: rawValue) ?? .blue
    }

    var color: Color {
        switch self {
        case .blue: return Color(light: "2F6BFF", dark: "5E9BFF")
        case .purple: return Color(light: "7A5AF8", dark: "A78BFA")
        case .pink: return Color(light: "C6339B", dark: "F472B6")
        case .red: return Color(light: "D62B2B", dark: "FF6B6B")
        case .orange: return Color(light: "E0700F", dark: "FF9F45")
        case .yellow: return Color(light: "C98800", dark: "FFC94A")
        case .green: return Color(light: "17875A", dark: "34D399")
        case .teal: return Color(light: "0E8FA8", dark: "38BEC9")
        case .gray: return Color(light: "5B6472", dark: "A6AEBC")
        }
    }

    var accessibilityName: String {
        switch self {
        case .blue: return String(localized: "Blue")
        case .purple: return String(localized: "Purple")
        case .pink: return String(localized: "Pink")
        case .red: return String(localized: "Red")
        case .orange: return String(localized: "Orange")
        case .yellow: return String(localized: "Yellow")
        case .green: return String(localized: "Green")
        case .teal: return String(localized: "Teal")
        case .gray: return String(localized: "Gray")
        }
    }
}
