//
//  PdfFileIntents.swift
//  PdfExpert
//
//  Intents that do the work without opening the app, so a PDF can be handed to
//  a shortcut, processed, and passed straight on to the next action.
//
//  They reuse the same utilities the in-app flows use, and they respect the
//  same premium gating — a paywall cannot be shown from a background intent, so
//  a gated tool reports why it stopped instead.
//

import AppIntents
import PDFKit
import UniformTypeIdentifiers
import Factory

enum PdfIntentError: Error, CustomLocalizedStringResourceConvertible {

    case notAPdf
    case emptyDocument
    case failed
    case premiumRequired
    case toolUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notAPdf: return "That file is not a PDF."
        case .emptyDocument: return "That PDF has no pages."
        case .failed: return "The PDF could not be processed."
        case .premiumRequired: return "This tool is part of the premium plan. Open the app to subscribe."
        case .toolUnavailable: return "That tool is not available right now."
        }
    }
}

/// Shared plumbing: decode the incoming file, run PDFKit work off the main
/// thread, and hand back a `.pdf` file Shortcuts can pass along.
enum PdfIntentSupport {

    static func document(from file: IntentFile) throws -> PDFDocument {
        guard let document = PDFDocument(data: file.data) else { throw PdfIntentError.notAPdf }
        guard document.pageCount > 0 else { throw PdfIntentError.emptyDocument }
        return document
    }

    static func intentFile(from document: PDFDocument, filename: String) throws -> IntentFile {
        guard let data = document.dataRepresentation() else { throw PdfIntentError.failed }
        return IntentFile(data: data, filename: filename, type: .pdf)
    }

    /// PDFKit work is synchronous and can be slow on big documents; keep it off
    /// the main thread so the app stays responsive when it is in the foreground.
    static func offMain<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: try work()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    @MainActor
    static func requirePremium() throws {
        guard Container.shared.store().isPremium.value else {
            throw PdfIntentError.premiumRequired
        }
    }

    /// "report.pdf" + "-merged" → "report-merged.pdf"
    static func filename(_ original: String, suffix: String) -> String {
        let base = original.hasSuffix(".pdf") ? String(original.dropLast(4)) : original
        return "\(base)\(suffix).pdf"
    }
}

// MARK: - Merge

struct MergePdfsIntent: AppIntent {

    static var title: LocalizedStringResource = "Merge PDFs"
    static var description = IntentDescription("Combines several PDFs into a single document, in the order given.")

    @Parameter(title: "PDFs", supportedTypeIdentifiers: ["com.adobe.pdf"])
    var files: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Merge \(\.$files)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let files = self.files
        guard files.count > 1 else { throw PdfIntentError.failed }

        let result = try await PdfIntentSupport.offMain {
            let merged = PDFDocument()
            for file in files {
                let document = try PdfIntentSupport.document(from: file)
                PDFUtility.appendPdfDocument(document, toPdfDocument: merged)
            }
            return try PdfIntentSupport.intentFile(from: merged, filename: "merged.pdf")
        }
        return .result(value: result)
    }
}

// MARK: - Rotate

enum PdfRotationDirection: String, AppEnum {

    case clockwise
    case counterclockwise

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Rotation"

    static var caseDisplayRepresentations: [PdfRotationDirection: DisplayRepresentation] = [
        .clockwise: "Clockwise",
        .counterclockwise: "Counterclockwise"
    ]
}

struct RotatePdfIntent: AppIntent {

    static var title: LocalizedStringResource = "Rotate PDF"
    static var description = IntentDescription("Rotates every page of a PDF.")

    @Parameter(title: "PDF", supportedTypeIdentifiers: ["com.adobe.pdf"])
    var file: IntentFile

    @Parameter(title: "Direction", default: .clockwise)
    var direction: PdfRotationDirection

    static var parameterSummary: some ParameterSummary {
        Summary("Rotate \(\.$file) \(\.$direction)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let file = self.file
        let clockwise = self.direction == .clockwise

        let result = try await PdfIntentSupport.offMain {
            let document = try PdfIntentSupport.document(from: file)
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                PDFUtility.rotatePage(page, clockwise: clockwise)
            }
            return try PdfIntentSupport.intentFile(from: document,
                                                   filename: PdfIntentSupport.filename(file.filename,
                                                                                       suffix: "-rotated"))
        }
        return .result(value: result)
    }
}

// MARK: - Remove blank pages

struct RemoveBlankPagesIntent: AppIntent {

    static var title: LocalizedStringResource = "Remove blank pages"
    static var description = IntentDescription("Finds and deletes the empty pages of a PDF.")

    @Parameter(title: "PDF", supportedTypeIdentifiers: ["com.adobe.pdf"])
    var file: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Remove blank pages from \(\.$file)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        let file = self.file

        let outcome = try await PdfIntentSupport.offMain { () -> (file: IntentFile, removed: Int) in
            let document = try PdfIntentSupport.document(from: file)
            let result = PdfCleanupUtility.removeBlankPages(from: document)
            let intentFile = try PdfIntentSupport.intentFile(from: result.document,
                                                             filename: PdfIntentSupport.filename(file.filename,
                                                                                                 suffix: "-cleaned"))
            return (intentFile, result.removedCount)
        }
        return .result(value: outcome.file,
                       dialog: IntentDialog("Removed \(outcome.removed) blank pages."))
    }
}

// MARK: - Extract text

struct ExtractPdfTextIntent: AppIntent {

    static var title: LocalizedStringResource = "Get text from PDF"
    static var description = IntentDescription("Returns the text of a PDF, ready to pass to another action.")

    @Parameter(title: "PDF", supportedTypeIdentifiers: ["com.adobe.pdf"])
    var file: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Get text from \(\.$file)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try await PdfIntentSupport.requirePremium()
        let file = self.file

        let text = try await PdfIntentSupport.offMain { () -> String in
            let document = try PdfIntentSupport.document(from: file)
            return PDFUtility.extractText(from: document)
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PdfIntentError.failed
        }
        return .result(value: text)
    }
}
