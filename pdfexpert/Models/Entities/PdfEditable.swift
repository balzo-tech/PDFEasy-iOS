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
    
    var rawData: Data? {
        return self.pdfDocument.dataRepresentation()
    }
    
    init?(data: Data) {
        guard let pdfDocument = PDFDocument(data: data) else { return nil }
        self.pdfDocument = pdfDocument
    }
    
    init(pdfDocument: PDFDocument) {
        self.pdfDocument = pdfDocument
    }
}
