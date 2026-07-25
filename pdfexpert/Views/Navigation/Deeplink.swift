//
//  Deeplink.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/08/23.
//

import Foundation

enum Deeplink {
    case chatPdf
    /// Opens a specific tab. Used by the share extension and, later, by
    /// Shortcuts / App Intents.
    case tab(MainTab)

    init?(fromCustomUrl url: URL) {
        guard url.absoluteString.starts(with: SharedStorage.schema) else {
            return nil
        }

        let host = url.absoluteString.dropFirst(SharedStorage.schema.count).lowercased()
        switch host {
        case "chatpdf":
            self = .chatPdf
        case "files":
            self = .tab(.files)
        case "tools":
            self = .tab(.tools)
        case "search":
            self = .tab(.search)
        default:
            return nil
        }
    }
}
