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
            let thumbnail = PDFUtility.generatePdfThumbnail(
                pdfDocument: internalPdfDocument,
                size: K.Misc.ThumbnailSize
            )
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
    
    var shareData: Data? {
        if let password = self.password, let pdfDocument = self.pdfDocument {
            if let encryptedPdfDocument = try? PDFUtility.addPassword(pdfDocument: pdfDocument, password: password) {
                if encryptedPdfDocument.unlock(withPassword: password) {
                    return encryptedPdfDocument.dataRepresentation() ?? self.data
                } else {
                    return self.data
                }
            } else {
                return self.data
            }
        } else {
            return self.data
        }
    }
    
    convenience init(context: NSManagedObjectContext, pdfData: Data, password: String?) {
        self.init(context: context)
        self.data = pdfData
        self.creationDate = Date()
        self.password = password
    }
}
