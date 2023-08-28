//
//  Pdf+Persistable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/08/23.
//

import Foundation
import CoreData
import PDFKit

extension Pdf: Persistable {
    
    typealias CDEntity = CDPdf
    
    func getSavedOrNewCoreDataEntity(context: NSManagedObjectContext) -> CDEntity? {
        
        guard let pdfData = self.rawData else {
            debugPrint(for: self, message: "Cannot get pdf raw data for given Pdf instance")
            return nil
        }
        
        let result: CDPdf = self.getSavedCoreDataEntity(context: context) ?? CDPdf(context: context)
        result.update(withPdf: self, pdfData: pdfData)
        return result
    }
    
    static func create(withCoreDataEntity coreDataEntity: some CDEntity) -> Self? {
        
        guard let pdfData = coreDataEntity.data, let pdfDocument = PDFDocument(data: pdfData) else {
            debugPrint(for: self, message: "Cannot get pdf document for given CDPdf instance")
            return nil
        }
        return Pdf(storeId: coreDataEntity.objectID,
                   pdfDocument: pdfDocument,
                   password: coreDataEntity.password,
                   creationDate: coreDataEntity.creationDate,
                   fileName: coreDataEntity.filename,
                   compression: CompressionOption(rawValue: coreDataEntity.compression) ?? K.Misc.PdfDefaultCompression,
                   margins: MarginsOption(rawValue: coreDataEntity.margins) ?? K.Misc.PdfDefaultMarginsOption)
    }
    
    static func fetchRequest() -> NSFetchRequest<CDPdf> {
        return NSFetchRequest<CDPdf>(entityName: "Pdf")
    }
}
