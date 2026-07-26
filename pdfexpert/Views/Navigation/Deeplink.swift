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
    /// Opens one saved document in the editor. The id is the Core Data object
    /// URI the widget snapshot carries.
    case document(id: String)

    /// Starts one tool, by the identifier `HomeAction` exposes.
    case tool(identifier: String)

    /// URL the widget uses to open a document.
    static func documentUrl(forId id: String) -> URL? {
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "\(SharedStorage.schema)document/\(encoded)")
    }

    /// URL the widget uses to start a tool.
    static func toolUrl(forIdentifier identifier: String) -> URL? {
        URL(string: "\(SharedStorage.schema)tool/\(identifier)")
    }

    init?(fromCustomUrl url: URL) {
        guard url.absoluteString.starts(with: SharedStorage.schema) else {
            return nil
        }

        let path = String(url.absoluteString.dropFirst(SharedStorage.schema.count))
        if path.lowercased().hasPrefix("document/") {
            let raw = String(path.dropFirst("document/".count))
            guard let id = raw.removingPercentEncoding, !id.isEmpty else { return nil }
            self = .document(id: id)
            return
        }
        if path.lowercased().hasPrefix("tool/") {
            let identifier = String(path.dropFirst("tool/".count))
            guard !identifier.isEmpty else { return nil }
            self = .tool(identifier: identifier)
            return
        }

        switch path.lowercased() {
        case "chatpdf":
            self = .chatPdf
        case "files":
            self = .tab(.files)
        case "tools":
            self = .tab(.tools)
        case "search":
            self = .tab(.search)
        case "scanner":
            self = .tab(.scanner)
        default:
            return nil
        }
    }
}
