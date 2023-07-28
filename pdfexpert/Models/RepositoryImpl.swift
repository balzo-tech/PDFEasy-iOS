//
//  RepositoryImpl.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 27/03/23.
//

import Foundation
import CoreData
import Factory
import CloudKit
import PDFKit

private let DiskFullErrorDomain: String = NSSQLiteErrorDomain
private let DiskFullErrorCode: Int = 13

extension Container {
    var repository: Factory<Repository> {
        self { RepositoryImpl() }.singleton
    }
}

class RepositoryImpl: Repository {
    
    @Injected(\.persistence) var persistence
    
    private var pdfManagedContext: NSManagedObjectContext {
        return self.persistence.container.viewContext
    }
    
    func savePdf(pdfEditable: PdfEditable) throws -> PdfEditable {
        
        guard let savedOrNewPdf = pdfEditable.getSavedOrNewPdf(context: self.pdfManagedContext) else {
            throw SaveError.unknownError
        }
        
        try self.saveChanges()
        
        // Must get the PdfEditable entity after having saved, because its ObjectId changes after having saved the object.
        guard let updatedPdfEditable = PdfEditable.create(withCoreDataPdf: savedOrNewPdf) else {
            throw SaveError.unknownError
        }
        
        return updatedPdfEditable
    }
    
    func getDoPdfExist() throws -> Bool {
        var result = false
        let request = CDPdf.fetchRequest()
        request.includesSubentities = false
        do {
            result = try self.persistence.container
                .viewContext.fetch(request).count > 0
        } catch {
            debugPrint(for: self, message: "Error while fetching stories")
            throw SharedUnderlyingError.convertError(fromError: error)
        }
        return result
    }
    
    func loadPdfs() throws -> [PdfEditable] {
        let fetchRequest = CDPdf.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        do {
            return try self.persistence.container.viewContext
                .fetch(fetchRequest)
                .map { pdf in
                    guard let pdfEditable = PdfEditable.create(withCoreDataPdf: pdf) else {
                        throw SharedUnderlyingError.unknownError
                    }
                    return pdfEditable
            }
        } catch {
            debugPrint(for: self, message: "Error while fetching stories")
            throw SharedUnderlyingError.convertError(fromError: error)
        }
    }
    
    func delete(pdfEditable: PdfEditable) throws {
        guard let storedPdf = pdfEditable.getSavedPdf(context: self.pdfManagedContext) else {
            debugPrint(for: self, message: "Current PdfEditable instance doesn't exist in the persistent storage")
            return
        }
        self.persistence.container.viewContext.delete(storedPdf)
        try self.saveChanges()
    }
    
    private func saveChanges() throws {
        guard self.persistence.container.viewContext.hasChanges else {
            return
        }
        
        do {
            try self.persistence.container.viewContext.save()
        } catch let error as NSError {
            debugPrint(for: self, message: "Error while saving the story. Error: \(error.localizedDescription)")
            if error.domain == DiskFullErrorDomain, error.code == DiskFullErrorCode {
                debugPrint(for: self, message: "Memory full error")
                throw SaveError.diskFullError
            } else {
                debugPrint(for: self, message: "Unhandled save error")
                throw SaveError.convertError(fromError: error)
            }
        }
    }
}

enum SaveError: UnderlyingError {
    case unknownError
    case diskFullError
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
}

fileprivate extension PdfEditable {
    
    func getSavedOrNewPdf(context: NSManagedObjectContext) -> CDPdf? {
        
        guard let pdfData = self.rawData else {
            debugPrint(for: self, message: "Cannot get pdf raw data for given PdfEditable instance")
            return nil
        }
        
        var result: CDPdf? = nil
        
        if let objectId = self.storeId {
            guard let savedPdf = (try? context.existingObject(with: objectId)) as? CDPdf else {
                debugPrint(for: self, message: "Cannot found expected CDPdf instance for given object id")
                return nil
            }
            result = savedPdf
        } else {
            result = CDPdf(context: context)
        }
        
        result?.update(withPdf: self, pdfData: pdfData)
        
        return result
    }
    
    func getSavedPdf(context: NSManagedObjectContext) -> CDPdf? {
        if let objectId = self.storeId {
            return (try? context.existingObject(with: objectId)) as? CDPdf
        } else {
            return nil
        }
    }
    
    static func create(withCoreDataPdf pdf: CDPdf) -> Self? {
        guard let pdfData = pdf.data, let pdfDocument = PDFDocument(data: pdfData) else {
            debugPrint(for: self, message: "Cannot get pdf document for given CDPdf instance")
            return nil
        }
        return PdfEditable(storeId: pdf.objectID,
                           pdfDocument: pdfDocument,
                           password: pdf.password,
                           creationDate: pdf.creationDate,
                           fileName: pdf.filename,
                           compression: CompressionOption(rawValue: pdf.compression) ?? K.Misc.PdfDefaultCompression,
                           margins: MarginsOption(rawValue: pdf.margins) ?? K.Misc.PdfDefaultMarginsOption)
    }
}
