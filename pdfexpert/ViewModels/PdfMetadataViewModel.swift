//
//  PdfMetadataViewModel.swift
//  PdfExpert
//
//  FREE-tier tool that exposes a PDF's document info (read-only) and lets the user
//  edit the standard metadata attributes (title, author, subject, creator,
//  keywords). Edits are written straight into the document's `documentAttributes`,
//  which serialize into `dataRepresentation()`, so persistence needs no schema
//  change. The input `Pdf` wraps a reference-type `PDFDocument`, so mutating its
//  attributes updates the same document the caller holds; on save the (updated)
//  `Pdf` is handed back via `onConfirm`.
//

import Foundation
import Factory
import PDFKit

extension Container {
    var pdfMetadataViewModel: ParameterFactory<PdfMetadataViewModel.InputParameter, PdfMetadataViewModel> {
        self { PdfMetadataViewModel(inputParameter: $0) }
    }
}

class PdfMetadataViewModel: ObservableObject {

    struct InputParameter {
        let pdf: Pdf
        let onConfirm: (Pdf) -> Void
    }

    // Editable metadata fields, initialized from the document attributes.
    @Published var title: String = ""
    @Published var author: String = ""
    @Published var subject: String = ""
    @Published var creator: String = ""
    // Comma-separated in the UI; split back into a `[String]` on save.
    @Published var keywords: String = ""

    // Read-only document info, captured once at init.
    let pageCount: Int
    let fileSizeText: String
    let pdfVersionText: String
    let isProtected: Bool
    let creationDateText: String
    let modificationDateText: String

    @Injected(\.analyticsManager) private var analyticsManager

    private let pdf: Pdf
    private let onConfirm: (Pdf) -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        self.onConfirm = inputParameter.onConfirm

        let document = inputParameter.pdf.pdfDocument
        let attributes = document.documentAttributes ?? [:]

        self.title = Self.string(attributes, .titleAttribute)
        self.author = Self.string(attributes, .authorAttribute)
        self.subject = Self.string(attributes, .subjectAttribute)
        self.creator = Self.string(attributes, .creatorAttribute)
        self.keywords = Self.keywordsString(attributes)

        self.pageCount = document.pageCount
        self.fileSizeText = Self.fileSize(inputParameter.pdf.rawData)
        self.pdfVersionText = "\(document.majorVersion).\(document.minorVersion)"
        self.isProtected = inputParameter.pdf.password != nil
        self.creationDateText = Self.date(attributes, .creationDateAttribute)
        self.modificationDateText = Self.date(attributes, .modificationDateAttribute)
    }

    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.metadata))
    }

    /// Writes the edited fields back into the document attributes (an empty /
    /// whitespace-only field removes its key), stamps the modification date, and
    /// hands the updated `Pdf` back to the caller.
    func save() {
        var attributes = self.pdf.pdfDocument.documentAttributes ?? [:]

        Self.setOrRemove(&attributes, .titleAttribute, self.title)
        Self.setOrRemove(&attributes, .authorAttribute, self.author)
        Self.setOrRemove(&attributes, .subjectAttribute, self.subject)
        Self.setOrRemove(&attributes, .creatorAttribute, self.creator)

        let keywordsList = self.keywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if keywordsList.isEmpty {
            attributes.removeValue(forKey: PDFDocumentAttribute.keywordsAttribute)
        } else {
            attributes[PDFDocumentAttribute.keywordsAttribute] = keywordsList
        }

        attributes[PDFDocumentAttribute.modificationDateAttribute] = Date()

        self.pdf.pdfDocument.documentAttributes = attributes
        self.analyticsManager.track(event: .pdfMetadataUpdated)
        self.onConfirm(self.pdf)
    }

    // MARK: - Attribute helpers

    private static func setOrRemove(_ attributes: inout [AnyHashable: Any],
                                    _ key: PDFDocumentAttribute,
                                    _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            attributes.removeValue(forKey: key)
        } else {
            attributes[key] = trimmed
        }
    }

    private static func string(_ attributes: [AnyHashable: Any],
                               _ key: PDFDocumentAttribute) -> String {
        (attributes[key] as? String) ?? ""
    }

    /// `keywordsAttribute` may hold either a `[String]` or a single `String`;
    /// normalize both into the comma-separated form used by the UI.
    private static func keywordsString(_ attributes: [AnyHashable: Any]) -> String {
        let value = attributes[PDFDocumentAttribute.keywordsAttribute]
        if let array = value as? [String] {
            return array.joined(separator: ", ")
        } else if let string = value as? String {
            return string
        }
        return ""
    }

    private static func date(_ attributes: [AnyHashable: Any],
                             _ key: PDFDocumentAttribute) -> String {
        guard let date = attributes[key] as? Date else { return "—" }
        return Self.dateFormatter.string(from: date)
    }

    private static func fileSize(_ data: Data?) -> String {
        guard let data else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}
