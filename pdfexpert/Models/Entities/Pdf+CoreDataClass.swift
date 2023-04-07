//
//  Pdf+CoreDataClass.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//
//

import Foundation
import CoreData
import UIKit
import PDFKit

@objc(Pdf)
public class Pdf: NSManagedObject {

    var internalThumbnail: UIImage?
    var internalPdfDocument: PDFDocument?
    
    var thumbnail: UIImage? {
        if let internalThumbnail = self.internalThumbnail {
            return internalThumbnail
        } else if let internalPdfDocument = self.pdfDocument {
            let thumbnail = PDFUtility.generatePdfThumbnail(pdfDocument: internalPdfDocument)
            self.internalThumbnail = thumbnail
            return thumbnail
        } else {
            return nil
        }
    }
    
    var pdfDocument: PDFDocument? {
        if let internalPdfDocument = self.internalPdfDocument {
            return internalPdfDocument
        } else if let data = self.data {
            let pdfDocument = PDFDocument(data: data)
            self.internalPdfDocument = pdfDocument
            return pdfDocument
        } else {
            return nil
        }
    }
    
    var pageCount: Int? {
        return self.pdfDocument?.pageCount
    }
    
    convenience init(context: NSManagedObjectContext, pdfData: Data) {
        self.init(context: context)
        self.data = pdfData
        self.creationDate = Date()
    }
}
