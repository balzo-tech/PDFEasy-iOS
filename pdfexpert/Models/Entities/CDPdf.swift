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

    convenience init(context: NSManagedObjectContext,
                     pdfData: Data,
                     password: String?,
                     creationDate: Date,
                     filename: String?,
                     compression: CompressionOption,
                     margins: MarginsOption
    ) {
        self.init(context: context)
        self.data = pdfData
        self.creationDate = creationDate
        self.password = password
        self.filename = filename
        self.compression = compression.rawValue
        self.margins = margins.rawValue
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
