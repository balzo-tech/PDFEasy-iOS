//
//  ScanIntents.swift
//  PdfExpert
//
//  The scanner, as Shortcuts and Siri see it.
//
//  It comes in two halves, because scanning does. Pointing a camera at a page
//  needs a person holding the phone, so `ScanDocumentIntent` opens the app on
//  the scanner, pre-set the way the shortcut asked for. Everything *after* the
//  shutter — straightening, cleaning up, assembling a PDF, reading the text —
//  needs no camera at all, so those run in the background on images the shortcut
//  already has and hand the result straight to the next action.
//
//  That second half is what makes the scanner composable: "take the photos my
//  colleague sent me and turn them into a straightened, black-and-white PDF" is
//  a shortcut, not a feature request.
//

import AppIntents
import PDFKit
import UIKit
import UniformTypeIdentifiers
import Factory

// MARK: - Shared types

/// `ScanFilter`, as a Shortcuts parameter.
enum ScanFilterAppEnum: String, AppEnum {

    case original
    case document
    case greyscale
    case blackAndWhite

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Scan filter"

    static var caseDisplayRepresentations: [ScanFilterAppEnum: DisplayRepresentation] = [
        .original: "Original",
        .document: "Document",
        .greyscale: "Greyscale",
        .blackAndWhite: "Black & white"
    ]

    var filter: ScanFilter {
        switch self {
        case .original: return .original
        case .document: return .document
        case .greyscale: return .grayscale
        case .blackAndWhite: return .blackAndWhite
        }
    }
}

enum ScanIntentError: Error, CustomLocalizedStringResourceConvertible {

    case noImages
    case notAnImage
    case failed
    case noText

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noImages: return "No images were given to scan."
        case .notAnImage: return "One of the files is not an image."
        case .failed: return "The pages could not be processed."
        case .noText: return "No text was found on those pages."
        }
    }
}

enum ScanIntentSupport {

    /// Decodes the incoming files and runs each one through the same detection
    /// and correction the camera uses, so a shortcut gets the app's scanner
    /// rather than a plain image-to-PDF.
    static func pages(from files: [IntentFile], filter: ScanFilter) async throws -> [ScannedPage] {
        guard !files.isEmpty else { throw ScanIntentError.noImages }

        let detector = DocumentDetector()
        var pages: [ScannedPage] = []
        for file in files {
            guard let image = UIImage(data: file.data) else { throw ScanIntentError.notAnImage }
            var quad: ScanQuad? = nil
            if let ciImage = ScanImageProcessor.ciImage(from: image) {
                quad = await detector.detect(in: ciImage)
            }
            pages.append(ScannedPage(original: image, quad: quad, filter: filter))
        }
        return pages
    }

    /// Rendering is Core Image work on images that can be very large; keep it
    /// off whatever thread the intent was called on.
    static func render(_ pages: [ScannedPage]) async -> [UIImage] {
        await Task.detached(priority: .userInitiated) {
            pages.compactMap { ScanImageProcessor.render($0, maxDimension: K.Misc.ScanPageMaxDimension) }
        }.value
    }
}

// MARK: - Open the scanner

/// Scanning needs the camera, so this opens the app on the scanner rather than
/// trying to run in the background. The filter carries over, which is what makes
/// "scan my receipts" different from "scan this contract".
struct ScanDocumentIntent: AppIntent {

    static var title: LocalizedStringResource = "Scan a document"
    static var description = IntentDescription("Opens the scanner to turn pages into a PDF.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Filter", default: .document)
    var filter: ScanFilterAppEnum

    @Parameter(title: "Automatic shutter", default: true)
    var automaticShutter: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Scan a document") {
            \.$filter
            \.$automaticShutter
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let request = ScanRequest(filter: self.filter.filter, automaticShutter: self.automaticShutter)
        Container.shared.mainCoordinator().startScan(request: request)
        return .result()
    }
}

// MARK: - Images in, PDF out

struct ScanImagesToPdfIntent: AppIntent {

    static var title: LocalizedStringResource = "Make a scanned PDF from images"
    static var description = IntentDescription(
        "Finds the page in each image, straightens it, cleans it up, and returns a PDF."
    )

    @Parameter(title: "Images", supportedTypeIdentifiers: ["public.image"])
    var images: [IntentFile]

    @Parameter(title: "Filter", default: .document)
    var filter: ScanFilterAppEnum

    @Parameter(title: "File name", default: "Scan")
    var filename: String

    static var parameterSummary: some ParameterSummary {
        Summary("Make a scanned PDF from \(\.$images)") {
            \.$filter
            \.$filename
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let pages = try await ScanIntentSupport.pages(from: self.images, filter: self.filter.filter)
        let document = await Task.detached(priority: .userInitiated) {
            PdfScanUtility.makeDocument(from: pages)
        }.value

        guard document.pageCount > 0, let data = document.dataRepresentation() else {
            throw ScanIntentError.failed
        }
        let name = self.filename.hasSuffix(".pdf") ? self.filename : "\(self.filename).pdf"
        return .result(value: IntentFile(data: data, filename: name, type: .pdf))
    }
}

// MARK: - Images in, images out

struct EnhanceScanImagesIntent: AppIntent {

    static var title: LocalizedStringResource = "Clean up scanned images"
    static var description = IntentDescription(
        "Straightens each page and applies a scanner filter, returning the images."
    )

    @Parameter(title: "Images", supportedTypeIdentifiers: ["public.image"])
    var images: [IntentFile]

    @Parameter(title: "Filter", default: .document)
    var filter: ScanFilterAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Clean up \(\.$images) with \(\.$filter)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let pages = try await ScanIntentSupport.pages(from: self.images, filter: self.filter.filter)
        let rendered = await ScanIntentSupport.render(pages)
        guard !rendered.isEmpty else { throw ScanIntentError.failed }

        let files = rendered.enumerated().compactMap { index, image -> IntentFile? in
            guard let data = image.jpegData(compressionQuality: K.Misc.ScanJpegQuality) else { return nil }
            return IntentFile(data: data, filename: "scan-\(index + 1).jpg", type: .jpeg)
        }
        guard files.count == rendered.count else { throw ScanIntentError.failed }
        return .result(value: files)
    }
}

// MARK: - Text off a page

struct ScanTextFromImagesIntent: AppIntent {

    static var title: LocalizedStringResource = "Get text from scanned images"
    static var description = IntentDescription(
        "Reads the text off photographed pages, straightening them first so the recognition has a flat page to work with."
    )

    @Parameter(title: "Images", supportedTypeIdentifiers: ["public.image"])
    var images: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Get text from \(\.$images)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try await PdfIntentSupport.requirePremium()

        // Straighten first: recognition on a page shot at an angle loses whole
        // lines, and the correction is the one thing this app can add over a
        // plain "extract text" action.
        let pages = try await ScanIntentSupport.pages(from: self.images, filter: .original)
        let rendered = await ScanIntentSupport.render(pages)
        guard !rendered.isEmpty else { throw ScanIntentError.failed }

        var text = ""
        for image in rendered {
            guard let cgImage = image.cgImage else { continue }
            let lines = OcrUtility.recognizeText(in: cgImage)
                .compactMap { $0.topCandidates(1).first?.string }
            guard !lines.isEmpty else { continue }
            if !text.isEmpty { text += "\n" }
            text += lines.joined(separator: "\n")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScanIntentError.noText
        }
        return .result(value: text)
    }
}

// MARK: - The scans already saved

/// A document the scanner produced, so a shortcut can find one and pass it on.
struct ScannedDocumentEntity: AppEntity {

    let id: String
    let name: String
    let pageCount: Int
    let creationDate: Date

    init(pdf: Pdf) {
        self.id = pdf.documentId
        self.name = pdf.displayName
        self.pageCount = pdf.pageCount
        self.creationDate = pdf.creationDate
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Scan", numericFormat: "\(placeholder: .int) scans")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(self.name)",
                              subtitle: "\(self.pageCount) pages",
                              image: .init(systemName: "doc.viewfinder"))
    }

    static var defaultQuery = ScannedDocumentQuery()
}

struct ScannedDocumentQuery: EntityStringQuery {

    @MainActor
    private func scans() -> [Pdf] {
        let pdfs = (try? Container.shared.repository().loadPdfs()) ?? []
        return pdfs
            .filter { $0.source == .scan }
            .sorted { $0.creationDate > $1.creationDate }
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [ScannedDocumentEntity] {
        self.scans()
            .filter { identifiers.contains($0.documentId) }
            .map(ScannedDocumentEntity.init(pdf:))
    }

    @MainActor
    func entities(matching string: String) async throws -> [ScannedDocumentEntity] {
        self.scans()
            .filter { ArchiveFilter.matches($0.filename, string) || ArchiveFilter.matches($0.searchableText, string) }
            .map(ScannedDocumentEntity.init(pdf:))
    }

    @MainActor
    func suggestedEntities() async throws -> [ScannedDocumentEntity] {
        self.scans().prefix(10).map(ScannedDocumentEntity.init(pdf:))
    }
}

/// Hands the PDF itself to the next action — the point of exposing the entity.
struct GetScanFileIntent: AppIntent {

    static var title: LocalizedStringResource = "Get a scan"
    static var description = IntentDescription("Returns one of your saved scans as a PDF file.")

    @Parameter(title: "Scan")
    var scan: ScannedDocumentEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$scan)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let pdfs = (try? Container.shared.repository().loadPdfs()) ?? []
        guard let pdf = pdfs.first(where: { $0.documentId == self.scan.id }),
              let data = pdf.rawData else {
            throw ScanIntentError.failed
        }
        return .result(value: IntentFile(data: data, filename: "\(pdf.displayName).pdf", type: .pdf))
    }
}

/// Opens a saved scan in the app, for the shortcuts that end in "…and show it
/// to me".
struct OpenScanIntent: AppIntent {

    static var title: LocalizedStringResource = "Open a scan"
    static var description = IntentDescription("Opens one of your saved scans in PDF Pro.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Scan")
    var scan: ScannedDocumentEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$scan)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let pdfs = (try? Container.shared.repository().loadPdfs()) ?? []
        guard let pdf = pdfs.first(where: { $0.documentId == self.scan.id }) else {
            throw ScanIntentError.failed
        }
        Container.shared.mainCoordinator().showPdfEditFlow(pdf: pdf, isNewPdf: false)
        return .result()
    }
}

/// Opens the Scanner tab without starting a capture — "show me my scans".
struct OpenScansIntent: AppIntent {

    static var title: LocalizedStringResource = "Show my scans"
    static var description = IntentDescription("Opens the Scanner tab in PDF Pro.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Container.shared.mainCoordinator().tab = .scanner
        return .result()
    }
}
