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
            intent: ScanDocumentIntent(),
            phrases: [
                "Scan a document with \(.applicationName)",
                "Scan a PDF with \(.applicationName)",
                "New scan in \(.applicationName)"
            ],
            shortTitle: "Scan a document",
            systemImageName: "doc.viewfinder"
        )
        AppShortcut(
            intent: OpenScansIntent(),
            phrases: [
                "Show my scans in \(.applicationName)",
                "Open the scanner in \(.applicationName)"
            ],
            shortTitle: "My scans",
            systemImageName: "doc.on.doc"
        )
        AppShortcut(
            intent: ScanImagesToPdfIntent(),
            phrases: [
                "Make a scanned PDF with \(.applicationName)",
                "Turn my photos into a scan with \(.applicationName)"
            ],
            shortTitle: "Scanned PDF from images",
            systemImageName: "doc.text.image"
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

// `ScanDocumentIntent` and the rest of the scanning actions live in
// `ScanIntents.swift`.
