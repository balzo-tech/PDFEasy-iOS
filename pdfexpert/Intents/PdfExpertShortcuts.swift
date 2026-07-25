//
//  PdfExpertShortcuts.swift
//  PdfExpert
//
//  The shortcuts offered in the Shortcuts app and to Siri without any setup.
//  Every phrase has to name the app, which is what `\(.applicationName)` does.
//

import AppIntents
import Factory

struct PdfExpertShortcuts: AppShortcutsProvider {

    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanDocumentShortcutIntent(),
            phrases: [
                "Scan a document with \(.applicationName)",
                "Scan a PDF with \(.applicationName)",
                "New scan in \(.applicationName)"
            ],
            shortTitle: "Scan a document",
            systemImageName: "doc.viewfinder"
        )
        AppShortcut(
            intent: OpenFilesIntent(),
            phrases: [
                "Open my documents in \(.applicationName)",
                "Show my PDFs in \(.applicationName)"
            ],
            shortTitle: "My documents",
            systemImageName: "folder"
        )
        AppShortcut(
            intent: MergePdfsIntent(),
            phrases: [
                "Merge PDFs with \(.applicationName)",
                "Combine PDFs with \(.applicationName)"
            ],
            shortTitle: "Merge PDFs",
            systemImageName: "arrow.trianglehead.merge"
        )
        AppShortcut(
            intent: RemoveBlankPagesIntent(),
            phrases: [
                "Remove blank pages with \(.applicationName)"
            ],
            shortTitle: "Remove blank pages",
            systemImageName: "rectangle.dashed"
        )
        AppShortcut(
            intent: OpenPdfToolIntent(),
            phrases: [
                "Open a tool in \(.applicationName)",
                "\(.applicationName) tools"
            ],
            shortTitle: "Open a tool",
            systemImageName: "square.grid.2x2"
        )
    }
}

/// Scanning needs the camera, so it opens the app on the scanner rather than
/// trying to run in the background.
struct ScanDocumentShortcutIntent: AppIntent {

    static var title: LocalizedStringResource = "Scan a document"
    static var description = IntentDescription("Opens the scanner to turn pages into a PDF.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Container.shared.mainCoordinator().runTool(.scan)
        return .result()
    }
}
