//
//  EditorTool.swift
//  PdfExpert
//
//  One description of everything the editor can do to the open document, and
//  one decision per entry about how it appears.
//
//  Before this there were four parallel lists — `PrimaryEdit`, `EditAction`,
//  `ActiveSheet` and `PdfEditStartAction` — plus the "…" menu, which wrote out
//  titles and symbols the tool catalog already carried. A tool added to the app
//  had to be added in four places to reach the editor, and its name could drift
//  in each of them. Here it is declared once, and its title, symbol, tint and
//  premium badge come from `ToolCatalog` whenever the catalog knows it.
//

import SwiftUI

/// How a tool reaches the user.
enum EditorToolPresentation {
    /// A screen pushed onto the editor's own stack: the tool asks a question,
    /// and the document stays one back-swipe away.
    case push
    /// Runs at once against the document, with no UI of its own beyond the
    /// progress and the result — rotate, flatten, invert, remove blank pages.
    case immediate
    /// The tool's own view model owns how it appears. What is left here is
    /// direct manipulation of the page — signing, filling in a form, redacting —
    /// where a navigation bar over the canvas would only be in the way, plus the
    /// two that are an alert rather than a screen.
    case flow
}

enum EditorTool: String, CaseIterable, Identifiable {

    // Page — the four in the bar under the page
    case rotateLeft
    case rotateRight
    case duplicatePage
    case deletePage
    case reorderPages

    // The frequent edits
    case addPage
    case signature
    case addText
    case fillForm

    // Organize
    case rotateAllPages
    case split
    case extractPages
    case removeBlankPages

    // Content
    case ocr
    case pageNumbers
    case watermark
    case invertColors
    case flatten

    // Protect
    case password
    case permissions
    case redact

    // Document
    case compress
    case export
    case metadata
    case share

    var id: String { self.rawValue }

    /// The catalog entry this tool corresponds to, when there is one. The
    /// catalog is the source of the user-facing name and symbol; the cases below
    /// only cover what the catalog has no entry for, because it is an editor
    /// gesture rather than a tool (rotating a page, say).
    var catalogAction: HomeAction? {
        switch self {
        case .split: return .split
        case .extractPages: return .extractPages
        case .removeBlankPages: return .removeBlankPages
        case .ocr: return .ocr
        case .pageNumbers: return .pageNumbers
        case .watermark: return .watermark
        case .invertColors: return .invertColors
        case .flatten: return .flattenPdf
        case .permissions: return .pdfPermissions
        case .redact: return .redactPdf
        case .compress: return .compressPdf
        case .export: return .exportPdf
        case .signature: return .sign
        case .addText: return .addText
        case .fillForm: return .formFill
        // `rotateAllPages` is deliberately not mapped to `.rotatePdf`: the catalog
        // entry covers the whole of rotating — one page or all of them — while
        // this is only the second half, next to a bar that already does the first.
        case .rotateLeft, .rotateRight, .rotateAllPages, .duplicatePage, .deletePage,
             .reorderPages, .addPage, .password, .metadata, .share:
            return nil
        }
    }

    private var catalogTool: PdfTool? {
        guard let action = self.catalogAction else { return nil }
        return ToolCatalog.allTools.first { $0.action == action }
    }

    var title: String {
        if let title = self.catalogTool?.title { return title }
        switch self {
        case .rotateLeft: return String(localized: "Rotate left")
        case .rotateRight: return String(localized: "Rotate right")
        case .rotateAllPages: return String(localized: "Rotate all pages")
        case .duplicatePage: return String(localized: "Duplicate page")
        case .deletePage: return String(localized: "Delete page")
        case .reorderPages: return String(localized: "Reorder pages")
        case .addPage: return String(localized: "Add page")
        case .password: return String(localized: "Password")
        case .metadata: return String(localized: "Document info")
        case .share: return String(localized: "Share")
        // Unreachable: everything else answers from the catalog. Falling back to
        // the case name would be a bug the user could read, so name it instead.
        default: return String(localized: "Tool")
        }
    }

    var systemImage: String {
        if let symbol = self.catalogTool?.systemImage { return symbol }
        switch self {
        case .rotateLeft: return "rotate.left"
        case .rotateRight, .rotateAllPages: return "rotate.right"
        case .duplicatePage: return "plus.rectangle.on.rectangle"
        case .deletePage: return "trash"
        case .reorderPages: return "arrow.up.arrow.down"
        case .addPage: return "plus"
        case .password: return "lock"
        case .metadata: return "info.circle"
        case .share: return "square.and.arrow.up"
        default: return "wrench.and.screwdriver"
        }
    }

    var category: ToolCategory? {
        if let category = self.catalogTool?.category { return category }
        // Listed in the panel next to the catalog's own organize tools, so it is
        // tinted like them rather than falling back to the accent color.
        return self == .rotateAllPages ? .organize : nil
    }

    var tint: Color { self.category?.tint ?? ColorPalette.accent }

    var presentation: EditorToolPresentation {
        switch self {
        case .rotateLeft, .rotateRight, .rotateAllPages, .duplicatePage,
             .removeBlankPages, .invertColors, .flatten, .ocr:
            return .immediate
        // Split, extract, export, compress and permissions are longer than a
        // question — an import, a form, a second document, an alert — but only
        // the form is a screen, and a screen is a screen wherever it came from.
        // Their view models still own the sequence; what they no longer own is
        // where the form appears (see `prepare` on each of them).
        case .reorderPages, .pageNumbers, .watermark, .metadata,
             .split, .extractPages, .export, .compress, .permissions:
            return .push
        case .signature, .addText, .fillForm, .redact,
             .password, .share, .addPage, .deletePage:
            return .flow
        }
    }

    /// Where a `.push` tool goes. Anything else answers `nil`.
    var route: EditorRoute? {
        switch self {
        case .reorderPages: return .reorderPages
        case .pageNumbers: return .pageNumbers
        case .watermark: return .watermark
        case .metadata: return .metadata
        case .split: return .split
        case .extractPages: return .extractPages
        case .export: return .export
        case .compress: return .compress
        case .permissions: return .permissions
        default: return nil
        }
    }

    /// Whether the tool needs at least one page to make sense.
    var needsPages: Bool { self != .addPage }

    /// Whether it needs more than one — reordering a single page is a no-op, and
    /// splitting one is worse than that.
    var needsSeveralPages: Bool {
        switch self {
        case .reorderPages, .split, .extractPages, .removeBlankPages: return true
        default: return false
        }
    }
}

// MARK: - The panel

/// How the tool panel groups what it shows. The first group has no catalog
/// category of its own; the rest borrow the catalog's, tints included, so the
/// editor and the Tools tab describe the same tool the same way.
struct EditorToolGroup: Identifiable {

    let id: String
    let title: String
    let tools: [EditorTool]

    /// Everything reachable from the panel, in the order it is shown. The page
    /// actions are deliberately absent: they live in the bar under the page,
    /// where they are one tap rather than three.
    static var all: [EditorToolGroup] {
        [
            EditorToolGroup(id: "pages",
                            title: String(localized: "Organize pages"),
                            tools: [.rotateAllPages, .reorderPages, .split, .extractPages, .removeBlankPages]),
            EditorToolGroup(id: "content",
                            title: String(localized: "Edit content"),
                            tools: [.ocr, .pageNumbers, .watermark, .invertColors, .flatten]),
            EditorToolGroup(id: "protect",
                            title: String(localized: "Protect"),
                            tools: [.password, .permissions, .redact]),
            EditorToolGroup(id: "document",
                            title: String(localized: "Document"),
                            tools: [.compress, .export, .metadata, .share])
        ]
    }

    /// Search over the same fields the catalog searches, so what the user types
    /// in the editor finds what it finds in the Tools tab.
    static func filtered(by query: String) -> [EditorToolGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return self.all }
        return self.all.compactMap { group in
            let matches = group.tools.filter { $0.matches(query: needle) }
            return matches.isEmpty ? nil : EditorToolGroup(id: group.id, title: group.title, tools: matches)
        }
    }
}

extension EditorTool {

    func matches(query: String) -> Bool {
        if let tool = self.catalogTool { return tool.matches(query: query) }
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return self.title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .contains(needle)
    }
}
