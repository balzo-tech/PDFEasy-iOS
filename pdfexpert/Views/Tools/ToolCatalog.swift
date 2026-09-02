//
//  ToolCatalog.swift
//  PdfExpert
//
//  One description of every tool the app offers, in one place: title, symbol,
//  family and whether it is premium. The Tools screen, the search results and
//  the document context menus all read from here, so a tool added once shows up
//  everywhere with the same name and icon.
//

import SwiftUI
import Factory

/// Tool families. Each carries its own tint, the way system utilities tint
/// their symbols, so the eye can navigate the catalog by color.
enum ToolCategory: Int, CaseIterable, Identifiable {

    case create
    case organize
    case edit
    case protect
    case export
    /// Tools that work on a photograph rather than on a document. Its own family
    /// on purpose: they are found by people looking for something the other five
    /// names do not describe, and keeping them here is what stops "Edit content"
    /// from quietly turning into a photo editor. Before `read`, which is one
    /// tool in a family of its own and makes a poor last row to scroll past.
    case image
    case read

    var id: Int { self.rawValue }

    var title: String {
        switch self {
        case .create: return String(localized: "Create a PDF")
        case .organize: return String(localized: "Organize pages")
        case .edit: return String(localized: "Edit content")
        case .protect: return String(localized: "Protect")
        case .export: return String(localized: "Convert from PDF")
        case .read: return String(localized: "Read")
        case .image: return String(localized: "Photos")
        }
    }

    var subtitle: String {
        switch self {
        case .create: return String(localized: "From photos, scans, Office files or the web")
        case .organize: return String(localized: "Merge, split, reorder and clean up")
        case .edit: return String(localized: "Sign, fill in, annotate and stamp")
        case .protect: return String(localized: "Passwords, permissions and redaction")
        case .export: return String(localized: "Turn your PDF into another format")
        case .read: return String(localized: "A distraction-free reader")
        case .image: return String(localized: "Work on a picture before it becomes a document")
        }
    }

    var systemImage: String {
        switch self {
        case .create: return "doc.badge.plus"
        case .organize: return "square.stack"
        case .edit: return "pencil.and.outline"
        case .protect: return "lock.shield"
        case .export: return "arrow.up.forward.square"
        case .read: return "book"
        case .image: return "photo.artframe"
        }
    }

    var tint: Color {
        switch self {
        case .create: return ColorPalette.categoryCreate
        case .organize: return ColorPalette.categoryOrganize
        case .edit: return ColorPalette.categoryEdit
        case .protect: return ColorPalette.categoryProtect
        case .export: return ColorPalette.categoryExport
        case .read: return ColorPalette.categoryRead
        case .image: return ColorPalette.categoryImage
        }
    }
}

extension HomeAction {

    /// Stable string id for the action. `HomeAction` carries no payload, so its
    /// case name is safe to persist and to hand to App Intents.
    var identifier: String { String(describing: self) }

    /// Resolves an identifier back to an action, limited to what the catalog
    /// currently offers (the online tools disappear when the service is off).
    init?(identifier: String) {
        guard let match = ToolCatalog.allTools.first(where: { $0.action.identifier == identifier }) else {
            return nil
        }
        self = match.action
    }
}

struct PdfTool: Identifiable, Hashable {

    let action: HomeAction
    let title: String
    let subtitle: String
    let systemImage: String
    let category: ToolCategory
    /// Extra terms the search matches on, beyond title and subtitle.
    var keywords: [String] = []

    var id: HomeAction { self.action }

    var tint: Color { self.category.tint }

    func matches(query: String) -> Bool {
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !needle.isEmpty else { return true }
        let haystack = ([self.title, self.subtitle] + self.keywords)
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return haystack.contains(needle)
    }
}

enum ToolCatalog {

    /// Every tool available right now. Tools that upload the document to the
    /// Stirling service are only listed when that service is reachable
    /// (remote-config kill switch + key), so the catalog reflects a config
    /// change on the next render.
    static var allTools: [PdfTool] {
        var tools: [PdfTool] = [

            // MARK: Create
            PdfTool(action: .scan,
                    title: String(localized: "Scan"),
                    subtitle: String(localized: "Capture pages with the camera"),
                    systemImage: "doc.viewfinder",
                    category: .create,
                    keywords: [String(localized: "camera"), String(localized: "document")]),
            PdfTool(action: .imageToPdf,
                    title: String(localized: "Image to PDF"),
                    subtitle: String(localized: "From your photo library"),
                    systemImage: "photo.on.rectangle.angled",
                    category: .create,
                    keywords: [String(localized: "photo"), String(localized: "gallery"), "jpg", "png"]),
            PdfTool(action: .wordToPdf,
                    title: String(localized: "Word to PDF"),
                    subtitle: String(localized: "DOC and DOCX files"),
                    systemImage: "doc.richtext",
                    category: .create,
                    keywords: ["doc", "docx", String(localized: "office")]),
            PdfTool(action: .excelToPdf,
                    title: String(localized: "Excel to PDF"),
                    subtitle: String(localized: "XLS and XLSX files"),
                    systemImage: "tablecells",
                    category: .create,
                    keywords: ["xls", "xlsx", String(localized: "spreadsheet")]),
            PdfTool(action: .powerpointToPdf,
                    title: String(localized: "Powerpoint to PDF"),
                    subtitle: String(localized: "PPT and PPTX files"),
                    systemImage: "rectangle.on.rectangle",
                    category: .create,
                    keywords: ["ppt", "pptx", String(localized: "slides")]),
            PdfTool(action: .webToPdf,
                    title: String(localized: "Web page to PDF"),
                    subtitle: String(localized: "Save any URL as a document"),
                    systemImage: "globe",
                    category: .create,
                    keywords: ["url", "html", String(localized: "website")]),
            PdfTool(action: .markdownToPdf,
                    title: String(localized: "Markdown to PDF"),
                    subtitle: String(localized: "Formatted text from Markdown"),
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    category: .create,
                    keywords: ["md", String(localized: "text")]),
            PdfTool(action: .createPdf,
                    title: String(localized: "Create PDF"),
                    subtitle: String(localized: "Start from a blank document"),
                    systemImage: "doc.badge.plus",
                    category: .create,
                    keywords: [String(localized: "blank"), String(localized: "new")]),
            PdfTool(action: .importPdf,
                    title: String(localized: "Import PDF"),
                    subtitle: String(localized: "Bring a file into your archive"),
                    systemImage: "tray.and.arrow.down",
                    category: .create,
                    keywords: [String(localized: "files"), String(localized: "open")]),
            // The import path opens these wherever they turn up, but a capability
            // with no name is a capability nobody knows about: this is the tile
            // someone finds when they search the app for the thing their bank,
            // notary or PEC mailbox just sent them. The wording promises reading,
            // never validation — see `SignedDocumentView`.
            PdfTool(action: .openSignedDocument,
                    title: String(localized: "Open signed document"),
                    subtitle: String(localized: "Take the PDF out of a .p7m file"),
                    systemImage: "doc.zipper",
                    category: .create,
                    keywords: ["p7m", "m7m", "p7s", "cades", "pec",
                               String(localized: "digital signature"),
                               String(localized: "signed"),
                               String(localized: "envelope")]),

            // MARK: Organize
            PdfTool(action: .merge,
                    title: String(localized: "Merge PDF"),
                    subtitle: String(localized: "Combine files into one"),
                    systemImage: "arrow.trianglehead.merge",
                    category: .organize,
                    keywords: [String(localized: "join"), String(localized: "combine")]),
            PdfTool(action: .split,
                    title: String(localized: "Split PDF"),
                    subtitle: String(localized: "Break a file into parts"),
                    systemImage: "scissors",
                    category: .organize,
                    keywords: [String(localized: "divide"), String(localized: "separate")]),
            PdfTool(action: .extractPages,
                    title: String(localized: "Extract pages"),
                    subtitle: String(localized: "Copy pages into a new file"),
                    systemImage: "doc.on.doc",
                    category: .organize,
                    keywords: [String(localized: "pages"), String(localized: "copy")]),
            PdfTool(action: .rotatePdf,
                    title: String(localized: "Rotate PDF"),
                    subtitle: String(localized: "Turn one page or all of them"),
                    systemImage: "rotate.right",
                    category: .organize,
                    keywords: [String(localized: "turn"), String(localized: "landscape")]),
            PdfTool(action: .removeBlankPages,
                    title: String(localized: "Remove blank pages"),
                    subtitle: String(localized: "Drop the empty ones"),
                    systemImage: "rectangle.dashed",
                    category: .organize,
                    keywords: [String(localized: "empty"), String(localized: "clean")]),

            // MARK: Edit
            PdfTool(action: .sign,
                    title: String(localized: "Sign PDF"),
                    subtitle: String(localized: "Draw or place your signature"),
                    systemImage: "signature",
                    category: .edit,
                    keywords: [String(localized: "signature"), String(localized: "sign")]),
            PdfTool(action: .formFill,
                    title: String(localized: "Fill in a form"),
                    subtitle: String(localized: "Type into form fields"),
                    systemImage: "list.bullet.rectangle.portrait",
                    category: .edit,
                    keywords: [String(localized: "form"), String(localized: "fields")]),
            PdfTool(action: .addText,
                    title: String(localized: "Add text"),
                    subtitle: String(localized: "Place text anywhere"),
                    systemImage: "textformat",
                    category: .edit,
                    keywords: [String(localized: "write"), String(localized: "annotate")]),
            PdfTool(action: .ocr,
                    title: String(localized: "Make Searchable (OCR)"),
                    subtitle: String(localized: "Make scans searchable"),
                    systemImage: "text.viewfinder",
                    category: .edit,
                    keywords: ["ocr", String(localized: "recognize"), String(localized: "searchable")]),
            PdfTool(action: .pageNumbers,
                    title: String(localized: "Page numbers"),
                    subtitle: String(localized: "Number every page"),
                    systemImage: "textformat.123",
                    category: .edit,
                    keywords: [String(localized: "numbering"), String(localized: "pagination")]),
            PdfTool(action: .watermark,
                    title: String(localized: "Watermark"),
                    subtitle: String(localized: "Stamp text across pages"),
                    systemImage: "drop.halffull",
                    category: .edit,
                    keywords: [String(localized: "stamp"), String(localized: "brand")]),
            PdfTool(action: .invertColors,
                    title: String(localized: "Invert colors"),
                    subtitle: String(localized: "Easier on the eyes at night"),
                    systemImage: "circle.lefthalf.filled",
                    category: .edit,
                    keywords: [String(localized: "dark"), String(localized: "negative")]),
            PdfTool(action: .flattenPdf,
                    title: String(localized: "Flatten PDF"),
                    subtitle: String(localized: "Bake in annotations and fields"),
                    systemImage: "square.stack.3d.down.forward",
                    category: .protect,
                    keywords: [String(localized: "merge layers"), String(localized: "lock content")]),

            // MARK: Protect
            PdfTool(action: .addPassword,
                    title: String(localized: "Protect PDF"),
                    subtitle: String(localized: "Lock it with a password"),
                    systemImage: "lock",
                    category: .protect,
                    keywords: [String(localized: "password"), String(localized: "encrypt")]),
            PdfTool(action: .removePassword,
                    title: String(localized: "Unlock PDF"),
                    subtitle: String(localized: "Remove a known password"),
                    systemImage: "lock.open",
                    category: .protect,
                    keywords: [String(localized: "password"), String(localized: "decrypt")]),
            PdfTool(action: .pdfPermissions,
                    title: String(localized: "PDF permissions"),
                    subtitle: String(localized: "Limit printing and copying"),
                    systemImage: "hand.raised",
                    category: .protect,
                    keywords: [String(localized: "print"), String(localized: "copy")]),
            PdfTool(action: .redactPdf,
                    title: String(localized: "Redact PDF"),
                    subtitle: String(localized: "Black out content for good"),
                    systemImage: "eye.slash",
                    category: .protect,
                    keywords: [String(localized: "hide"), String(localized: "censor")]),
            PdfTool(action: .comparePdf,
                    title: String(localized: "Compare PDFs"),
                    subtitle: String(localized: "See what changed between two files"),
                    systemImage: "arrow.left.arrow.right.square",
                    category: .organize,
                    keywords: [String(localized: "diff"), String(localized: "differences"), String(localized: "versions")]),
            PdfTool(action: .compressPdf,
                    title: String(localized: "Compress PDF"),
                    subtitle: String(localized: "Make the file smaller"),
                    systemImage: "arrow.down.right.and.arrow.up.left",
                    category: .organize,
                    keywords: [String(localized: "shrink"), String(localized: "size"), String(localized: "reduce")]),

            // MARK: Export
            PdfTool(action: .exportPdf,
                    title: String(localized: "Export PDF as…"),
                    subtitle: String(localized: "Images, text or embedded photos"),
                    systemImage: "square.and.arrow.up.on.square",
                    category: .export,
                    keywords: [String(localized: "images"), String(localized: "text"), "jpg", "txt"]),

            // MARK: Photos
            // First in its family, and the reason the family exists. The
            // keywords are the ones the App Store says people actually type —
            // `fototessera`, `foto carnet`, `Passbild`, `3x4` — rather than the
            // words on the tile, which nobody searches for.
            PdfTool(action: .passportPhoto,
                    title: String(localized: "Passport photo"),
                    subtitle: String(localized: "The right size for your country, checked before you print"),
                    systemImage: "person.crop.rectangle",
                    category: .image,
                    keywords: [String(localized: "passport photo"),
                               String(localized: "id photo"),
                               String(localized: "visa photo"),
                               "fototessera", "foto carnet", "passbild", "3x4", "35x45", "2x2",
                               String(localized: "biometric")]),
            PdfTool(action: .removeBackground,
                    title: String(localized: "Remove background"),
                    subtitle: String(localized: "Cut the subject out of a photo"),
                    systemImage: "person.and.background.dotted",
                    category: .image,
                    keywords: [String(localized: "background"), String(localized: "cut out"),
                               String(localized: "transparent"), String(localized: "erase"),
                               "png", String(localized: "photo")]),

            // MARK: Read
            PdfTool(action: .readPdf,
                    title: String(localized: "Read PDF"),
                    subtitle: String(localized: "A calm, full-screen reader"),
                    systemImage: "book",
                    category: .read,
                    keywords: [String(localized: "reader"), String(localized: "annotate")])
        ]

        if Container.shared.stirlingApiManager().isAvailable {
            tools.append(contentsOf: [
                PdfTool(action: .repairPdf,
                        title: String(localized: "Repair PDF"),
                        subtitle: String(localized: "Fix a damaged file"),
                        systemImage: "wrench.and.screwdriver",
                        category: .organize,
                            keywords: [String(localized: "fix"), String(localized: "damaged")]),
                PdfTool(action: .sanitizePdf,
                        title: String(localized: "Sanitize PDF"),
                        subtitle: String(localized: "Strip scripts and attachments"),
                        systemImage: "shield.checkered",
                        category: .protect,
                            keywords: [String(localized: "clean"), String(localized: "scripts")]),
                PdfTool(action: .pdfToWord,
                        title: String(localized: "PDF to Word"),
                        subtitle: String(localized: "Editable .docx"),
                        systemImage: "doc.text",
                        category: .export,
                            keywords: ["doc", "docx", String(localized: "office")]),
                PdfTool(action: .pdfToPowerpoint,
                        title: String(localized: "PDF to PowerPoint"),
                        subtitle: String(localized: "Editable .pptx"),
                        systemImage: "rectangle.on.rectangle",
                        category: .export,
                            keywords: ["ppt", "pptx", String(localized: "slides")]),
                PdfTool(action: .pdfToExcel,
                        title: String(localized: "PDF to Excel"),
                        subtitle: String(localized: "Tables as .csv"),
                        systemImage: "tablecells",
                        category: .export,
                            keywords: ["xls", "csv", String(localized: "spreadsheet")]),
                PdfTool(action: .pdfToPdfa,
                        title: String(localized: "PDF/A"),
                        subtitle: String(localized: "Archival format, built to last"),
                        systemImage: "checkmark.seal",
                        category: .export,
                            keywords: ["pdfa", String(localized: "archive")])
            ])
        }
        return tools
    }

    static func tools(inCategory category: ToolCategory) -> [PdfTool] {
        self.allTools.filter { $0.category == category }
    }

    static func tool(forAction action: HomeAction) -> PdfTool? {
        self.allTools.first { $0.action == action }
    }

    /// The shortcuts offered at the top of the Tools screen, before the user
    /// has built any history of their own.
    static let defaultQuickActions: [HomeAction] = [.scan, .imageToPdf, .merge, .sign, .readPdf]
}
