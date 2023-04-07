//
//  PdfUtility.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import Foundation
import PDFKit
import CoreData

class PDFUtility {
    
    static func generatePdfThumbnail(documentData: Data) -> UIImage? {
        guard let pdfDocument = PDFDocument(data: documentData) else { return nil }
        return self.generatePdfThumbnail(pdfDocument: pdfDocument)
    }
    
    static func generatePdfThumbnail(pdfDocument: PDFDocument) -> UIImage? {
        guard pdfDocument.pageCount > 0 else { return nil }
        let pdfDocumentPage = pdfDocument.page(at: 0)
        return pdfDocumentPage?.thumbnail(of: K.Misc.ThumbnailSize, for: PDFDisplayBox.trimBox)
    }
}
