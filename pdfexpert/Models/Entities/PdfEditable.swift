//
//  PdfEditable.swift
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
    case low, medium, high
}

struct PdfEditable {
    private(set) var storeId: NSManagedObjectID? = nil
    private(set) var pdfDocument: PDFDocument
    private(set) var password: String? = nil
    private(set) var creationDate: Date = Date()
    private(set) var filename: String
    private(set) var compression: CompressionOption = K.Misc.PdfDefaultCompression
    private(set) var margins: MarginsOption = K.Misc.PdfDefaultMarginsOption
    
    var rawData: Data? {
        return self.pdfDocument.dataRepresentation()
    }
    
    init(storeId: NSManagedObjectID,
         pdfDocument: PDFDocument,
         password: String?,
         creationDate: Date?,
         fileName: String?,
         compression: CompressionOption,
         margins: MarginsOption) {
        self.storeId = storeId
        self.pdfDocument = pdfDocument
        self.password = password
        self.creationDate = creationDate ?? Date()
        self.filename = fileName ?? self.creationDate.creationDateText
        self.compression = compression
        self.margins = margins
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
    
    mutating func updateCompression(_ newCompression: CompressionOption) {
        self.compression = newCompression
    }
    
    mutating func updateMargins(_ newMargins: MarginsOption) {
        self.margins = newMargins
    }
    
    mutating func updateFilename(_ filename: String) {
        self.filename = filename
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

extension PdfEditable: Hashable, Identifiable {
    var id: Self { return self }
}
