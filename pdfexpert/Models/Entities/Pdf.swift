//
//  Pdf.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import PDFKit
import CoreData

enum MarginsOption: Int32, CaseIterable {
    case noMargins, mediumMargins, heavyMargins
}

enum CompressionOption: Int32, CaseIterable {
    case noCompression, low, medium, high
}

/// Where a document came from. Only the scanner sets anything other than
/// `.unknown`: the Scanner tab lists what the camera produced, and it needs a
/// way to tell those documents apart from imported and converted ones. Stored
/// as an optional integer so every document already in the archive keeps
/// reading back — and so the tab is simply empty on a fresh install rather than
/// wrong.
enum PdfSource: Int32, CaseIterable {
    case unknown = 0
    case scan = 1
}

struct Pdf {
    private(set) var storeId: NSManagedObjectID? = nil
    private(set) var pdfDocument: PDFDocument
    private(set) var password: String? = nil
    private(set) var creationDate: Date = Date()
    private(set) var filename: String
    private(set) var compression: CompressionOption = K.Misc.PdfDefaultCompression
    private(set) var margins: MarginsOption = K.Misc.PdfDefaultMarginsOption
    // Indexed page text loaded from Core Data; used for the archive's full-text
    // search. nil for documents saved before indexing or never re-saved.
    private(set) var searchableText: String? = nil
    // Filing, loaded from the Core Data relationships. Read-only here on purpose:
    // both are changed through `Repository.setFolder`/`setTags`, which touch the
    // relationship alone instead of rewriting the document blob.
    private(set) var folder: Folder? = nil
    private(set) var tags: [Tag] = []
    private(set) var source: PdfSource = .unknown

    var rawData: Data? {
        return self.pdfDocument.dataRepresentation()
    }

    init(storeId: NSManagedObjectID,
         pdfDocument: PDFDocument,
         password: String?,
         creationDate: Date?,
         fileName: String?,
         compression: CompressionOption,
         margins: MarginsOption,
         searchableText: String? = nil,
         folder: Folder? = nil,
         tags: [Tag] = [],
         source: PdfSource = .unknown) {
        self.storeId = storeId
        self.pdfDocument = pdfDocument
        self.password = password
        self.creationDate = creationDate ?? Date()
        self.filename = fileName ?? self.creationDate.creationDateText
        self.compression = compression
        self.margins = margins
        self.searchableText = searchableText
        self.folder = folder
        self.tags = tags
        self.source = source
    }

    /// A document straight out of the scanner.
    init(pdfDocument: PDFDocument, filename: String, source: PdfSource) {
        self.pdfDocument = pdfDocument
        self.filename = filename
        self.source = source
    }
    
    init?(data: Data) {
        guard let pdfDocument = PDFDocument(data: data) else { return nil }
        self.pdfDocument = pdfDocument
        self.filename = self.creationDate.creationDateText
    }
    
    init?(pdfUrl: URL) {
        guard let pdfDocument = PDFDocument(url: pdfUrl) else { return nil }
        self.pdfDocument = pdfDocument
        self.filename = pdfUrl.filename
    }
    
    init(pdfDocument: PDFDocument) {
        self.pdfDocument = pdfDocument
        self.filename = self.creationDate.creationDateText
    }
    
    init() {
        self.pdfDocument = PDFDocument()
        self.filename = self.creationDate.creationDateText
    }
    
    mutating func updateStoreId(_ storeId: NSManagedObjectID?) {
        self.storeId = storeId
    }
    
    mutating func updateDocument(_ pdfDocument: PDFDocument) {
        self.pdfDocument = pdfDocument
    }
    
    mutating func updatePassword(_ newPassword: String?) {
        self.password = newPassword
    }
    
    // No setters for `compression` and `margins`: nothing in the app sets either
    // any more. They are read back from the store so old documents round-trip
    // unchanged, and that is all they are for.


    mutating func updateFilename(_ filename: String) {
        self.filename = filename
    }

    /// Mirrors a filing change already persisted by the repository, so callers
    /// get an up-to-date value without re-reading (and re-parsing) the document.
    mutating func updateFolder(_ folder: Folder?) {
        self.folder = folder
    }

    mutating func updateTags(_ tags: [Tag]) {
        self.tags = tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    var thumbnail: UIImage? {
        PDFUtility.generatePdfThumbnail(pdfDocument: self.pdfDocument, size: K.Misc.ThumbnailSize)
    }
    
    var pageCount: Int {
        return self.pdfDocument.pageCount
    }
}

fileprivate extension Date {
    
    var creationDateText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-YYYY"
        return "File-\(dateFormatter.string(from: self))"
    }
}

extension Pdf: Hashable, Identifiable {
    var id: Self { return self }
}

extension Pdf {

    /// True while the document still carries the name the app generated for it
    /// — `File-07-26-2026` for an import, `Scan 2026-07-26 14.49.26` for a scan.
    /// That is, nobody has named it yet: the editor only proposes a name in that
    /// case, because a document already called something is called that on
    /// purpose.
    static func isGeneratedFilename(_ filename: String) -> Bool {
        let patterns = ["^File-\\d{2}-\\d{2}-\\d{4}$",
                        "^Scan \\d{4}-\\d{2}-\\d{2} \\d{2}\\.\\d{2}\\.\\d{2}$"]
        return patterns.contains { filename.range(of: $0, options: .regularExpression) != nil }
    }
}

extension Pdf {

    /// Identity that survives a reload. The synthesized `Hashable` above follows
    /// the `PDFDocument` instance, so a document re-read from the store never
    /// equals the copy a view is still holding — no good for a selection that has
    /// to outlive a refresh. The store URI does survive, and it is already what
    /// the widget and the deeplinks use; a document not yet saved falls back to
    /// its filename.
    var documentId: String {
        self.storeId?.uriRepresentation().absoluteString ?? self.filename
    }
}

extension Pdf: Collection {
    
    typealias Index = Int
    typealias Element = PDFPage
    
    var startIndex: Index { return 0 }
    var endIndex: Index { return self.pageCount }
    
    subscript(index: Index) -> Element {
        get { return self.pdfDocument.page(at: index)! }
    }
    
    func index(after i: Index) -> Index {
        return i + 1
    }
}
