//
//  PdfEditable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import PDFKit
import CoreData

struct PdfEditable {
    private(set) var storeId: NSManagedObjectID?
    private(set) var pdfDocument: PDFDocument
    private(set) var password: String?
    private(set) var creationDate: Date?
    
    var rawData: Data? {
        return self.pdfDocument.dataRepresentation()
    }
    
    init?(storeId: NSManagedObjectID?, data: Data, password: String? = nil, creationDate: Date? = nil) {
        guard let pdfDocument = PDFDocument(data: data) else { return nil }
        self.storeId = storeId
        self.pdfDocument = pdfDocument
        self.password = password
        self.creationDate = creationDate
    }
    
    init?(storeId: NSManagedObjectID?, pdfUrl: URL, password: String? = nil, creationDate: Date? = nil) {
        guard let pdfDocument = PDFDocument(url: pdfUrl) else { return nil }
        self.storeId = storeId
        self.pdfDocument = pdfDocument
        self.password = password
        self.creationDate = creationDate
    }
    
    init(storeId: NSManagedObjectID?, pdfDocument: PDFDocument? = nil, password: String? = nil, creationDate: Date? = nil) {
        self.storeId = storeId
        self.pdfDocument = pdfDocument ?? PDFDocument()
        self.password = password
        self.creationDate = creationDate
    }
    
    init(storeId: NSManagedObjectID, pdfDocument: PDFDocument, password: String? = nil, creationDate: Date? = nil) {
        self.storeId = storeId
        self.pdfDocument = pdfDocument
        self.password = password
        self.creationDate = creationDate
    }
    
    mutating func updatePassword(_ newPassword: String?) {
        self.password = newPassword
    }
    
    var shareData: Data? {
        if let password = self.password {
            if let encryptedPdfDocument = PDFUtility.encryptPdf(pdfDocument: pdfDocument, password: password) {
                if encryptedPdfDocument.unlock(withPassword: password) {
                    return encryptedPdfDocument.dataRepresentation() ?? self.rawData
                } else {
                    return self.rawData
                }
            } else {
                return self.rawData
            }
        } else {
            return self.rawData
        }
    }
    
    var thumbnail: UIImage? {
        PDFUtility.generatePdfThumbnail(pdfDocument: self.pdfDocument, size: K.Misc.ThumbnailSize)
    }
    
    var pageCount: Int {
        return self.pdfDocument.pageCount
    }
}

extension PdfEditable: Hashable, Identifiable {
    var id: Self { return self }
}
