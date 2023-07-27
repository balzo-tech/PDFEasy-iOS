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
    
    var pdfDocument: PDFDocument? {
        guard let data = self.data else {
            return nil
        }
        return PDFDocument(data: data)
    }
    
    convenience init(context: NSManagedObjectContext, pdfData: Data, password: String?, creationDate: Date) {
        self.init(context: context)
        self.data = pdfData
        self.creationDate = creationDate
        self.password = password
    }
}
