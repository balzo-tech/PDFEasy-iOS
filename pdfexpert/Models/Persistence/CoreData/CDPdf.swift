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
    
    /// Note that this deliberately leaves `folder` and `tags` alone: filing is
    /// changed through the repository's own methods, so a plain document save
    /// (every edit goes through one) can never drop it.
    func update(withPdf pdf: Pdf, pdfData: Data) {
        self.data = pdfData
        self.creationDate = pdf.creationDate
        self.password = pdf.password
        self.filename = pdf.filename
        self.compression = pdf.compression.rawValue
        self.margins = pdf.margins.rawValue
        // Index the document text on save so the archive can full-text search it.
        // Empty for non-OCR'd scans (run OCR to make them searchable).
        self.searchableText = PDFUtility.extractText(from: pdf.pdfDocument)
    }

    /// The attached tags as domain values, name-sorted so a document shows them
    /// in the same order everywhere (a Core Data to-many set has no order).
    var tagList: [Tag] {
        let tags = (self.tags as? Set<CDTag>) ?? []
        return tags
            .compactMap { Tag.create(withCoreDataEntity: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

extension CDPdf {
    @NSManaged public var data: Data?
    @NSManaged public var creationDate: Date?
    @NSManaged public var password: String?
    @NSManaged public var filename: String?
    @NSManaged public var compression: Int32
    @NSManaged public var margins: Int32
    @NSManaged public var searchableText: String?
    @NSManaged public var folder: CDFolder?
    @NSManaged public var tags: NSSet?
}
