//
//  CDPdf.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//
//

import Foundation
import CoreData

@objc(CDPdf)
public class CDPdf: NSManagedObject {
    
    func update(withPdf pdf: PdfEditable, pdfData: Data) {
        self.data = pdfData
        self.creationDate = pdf.creationDate
        self.password = pdf.password
        self.filename = pdf.filename
        self.compression = pdf.compression.rawValue
        self.margins = pdf.margins.rawValue
    }
}

extension CDPdf {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDPdf> {
        return NSFetchRequest<CDPdf>(entityName: "Pdf")
    }

    @NSManaged public var data: Data?
    @NSManaged public var creationDate: Date?
    @NSManaged public var password: String?
    @NSManaged public var filename: String?
    @NSManaged public var compression: Int32
    @NSManaged public var margins: Int32
}
