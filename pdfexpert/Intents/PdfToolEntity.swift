//
//  PdfToolEntity.swift
//  PdfExpert
//
//  Exposes the tool catalog to Shortcuts and Siri, so "open the Merge tool"
//  works without the app having to enumerate its features twice.
//

import AppIntents
import SwiftUI

struct PdfToolEntity: AppEntity {

    let id: String
    let name: String
    let subtitle: String
    let systemImage: String

    init(tool: PdfTool) {
        self.id = tool.action.identifier
        self.name = tool.title
        self.subtitle = tool.subtitle
        self.systemImage = tool.systemImage
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "PDF tool", numericFormat: "\(placeholder: .int) tools")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(self.name)",
                              subtitle: "\(self.subtitle)",
                              image: .init(systemName: self.systemImage))
    }

    static var defaultQuery = PdfToolQuery()
}

struct PdfToolQuery: EntityStringQuery {

    private var allEntities: [PdfToolEntity] {
        ToolCatalog.allTools.map(PdfToolEntity.init(tool:))
    }

    func entities(for identifiers: [String]) async throws -> [PdfToolEntity] {
        self.allEntities.filter { identifiers.contains($0.id) }
    }

    /// Matches what the user says or types against the same fields the in-app
    /// search uses, keywords included.
    func entities(matching string: String) async throws -> [PdfToolEntity] {
        ToolCatalog.allTools
            .filter { $0.matches(query: string) }
            .map(PdfToolEntity.init(tool:))
    }

    func suggestedEntities() async throws -> [PdfToolEntity] {
        ToolUsageTracker.quickActions(from: ToolCatalog.allTools).map(PdfToolEntity.init(tool:))
    }
}
