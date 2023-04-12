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
    
    static func convertUiImageToPdf(uiImage: UIImage) -> PDFDocument {
        let pdfDocument = PDFDocument()
        appendImageToPdfDocument(pdfDocument: pdfDocument, uiImage: uiImage)
        return pdfDocument
    }
    
    static func appendImageToPdfDocument(pdfDocument: PDFDocument, uiImage: UIImage) {
        if let pdfPage = PDFPage(image: uiImage) {
            pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
        } else {
            assertionFailure("Couldn't create pdf page from given UIImage")
        }
    }
    
    static func generatePdfThumbnail(documentData: Data,
                                     size: CGSize,
                                     forPageIndex pageIndex: Int = 0) -> UIImage? {
        guard let pdfDocument = PDFDocument(data: documentData) else { return nil }
        return self.generatePdfThumbnail(pdfDocument: pdfDocument,
                                         size: size,
                                         forPageIndex: pageIndex)
    }
    
    static func generatePdfThumbnail(pdfDocument: PDFDocument,
                                     size: CGSize,
                                     forPageIndex pageIndex: Int = 0) -> UIImage? {
        guard pageIndex >= 0, pageIndex < pdfDocument.pageCount else { return nil }
        let pdfDocumentPage = pdfDocument.page(at: pageIndex)
        let nativeScale = UIScreen.main.nativeScale
        let nativeSize = CGSize(width: size.width * nativeScale, height: size.height * nativeScale)
        return pdfDocumentPage?.thumbnail(of: nativeSize, for: PDFDisplayBox.trimBox)
    }
}
