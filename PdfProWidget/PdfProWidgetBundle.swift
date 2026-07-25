//
//  PdfProWidgetBundle.swift
//  PdfProWidget
//
//  Two widgets: the documents you were last working on, and the tools you reach
//  for most. Both open the app through the custom URL scheme rather than through
//  App Intents, so the extension stays free of the app's dependency graph.
//

import WidgetKit
import SwiftUI

@main
struct PdfProWidgetBundle: WidgetBundle {

    var body: some Widget {
        RecentDocumentsWidget()
        QuickActionsWidget()
    }
}

/// The URL scheme differs per environment, exactly as it does in the app.
enum WidgetLinks {

    #if STAGING
    static let schema = "pdfprostaging://"
    #else
    static let schema = "pdfpro://"
    #endif

    static func document(_ id: String) -> URL? {
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "\(Self.schema)document/\(encoded)")
    }

    static func tool(_ identifier: String) -> URL? {
        URL(string: "\(Self.schema)tool/\(identifier)")
    }

    static var files: URL? { URL(string: "\(Self.schema)files") }
}

/// Palette kept in step with the app's accent, without dragging the whole
/// design system into the extension.
enum WidgetPalette {

    static let accent = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.62, blue: 1.00, alpha: 1)
            : UIColor(red: 0.04, green: 0.39, blue: 0.91, alpha: 1) }
    )
    static let textSecondary = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.65, green: 0.68, blue: 0.74, alpha: 1)
            : UIColor(red: 0.36, green: 0.39, blue: 0.45, alpha: 1) }
    )
    static let placeholder = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.16, blue: 0.19, alpha: 1)
            : UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1) }
    )
}
