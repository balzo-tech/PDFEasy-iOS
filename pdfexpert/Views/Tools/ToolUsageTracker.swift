//
//  ToolUsageTracker.swift
//  PdfExpert
//
//  Remembers which tools the user actually reaches for, so the top of the Tools
//  screen adapts instead of showing a fixed "most used" list picked at design
//  time.
//

import Foundation

enum ToolUsageTracker {

    private static let storageKey = "recentToolActions"
    private static let maxCount = 5

    /// Stable string id for an action. `HomeAction` carries no payload, so its
    /// case name is a safe key to persist.
    private static func identifier(for action: HomeAction) -> String {
        String(describing: action)
    }

    static func registerUse(of action: HomeAction) {
        var identifiers = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        let identifier = Self.identifier(for: action)
        identifiers.removeAll { $0 == identifier }
        identifiers.insert(identifier, at: 0)
        UserDefaults.standard.set(Array(identifiers.prefix(Self.maxCount)), forKey: Self.storageKey)
    }

    /// Most recently used tools first, padded with the default shortcuts so the
    /// strip is never half empty. Only tools currently in the catalog are kept
    /// (the online ones disappear when the service is unavailable).
    static func quickActions(from catalog: [PdfTool]) -> [PdfTool] {
        let byIdentifier = Dictionary(catalog.map { (Self.identifier(for: $0.action), $0) },
                                      uniquingKeysWith: { first, _ in first })
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []

        var result: [PdfTool] = stored.compactMap { byIdentifier[$0] }
        for action in ToolCatalog.defaultQuickActions where result.count < Self.maxCount {
            guard let tool = catalog.first(where: { $0.action == action }),
                  !result.contains(where: { $0.action == action }) else { continue }
            result.append(tool)
        }
        return Array(result.prefix(Self.maxCount))
    }
}
