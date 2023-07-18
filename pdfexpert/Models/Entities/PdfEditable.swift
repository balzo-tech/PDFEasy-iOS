//
//  PdfEditable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import PDFKit

struct PdfEditable {
    private(set) var pdfDocument: PDFDocument
    private(set) var password: String?
    
    var rawData: Data? {
        return self.pdfDocument.dataRepresentation()
    }
    
    init?(data: Data, password: String? = nil) {
        guard let pdfDocument = PDFDocument(data: data) else { return nil }
        self.pdfDocument = pdfDocument
        self.password = password
    }
    
    init?(pdfUrl: URL, password: String? = nil) {
        guard let pdfDocument = PDFDocument(url: pdfUrl) else { return nil }
        self.pdfDocument = pdfDocument
        self.password = password
    }
    
    init(pdfDocument: PDFDocument? = nil, password: String? = nil) {
        self.pdfDocument = pdfDocument ?? PDFDocument()
        self.password = password
    }
}
