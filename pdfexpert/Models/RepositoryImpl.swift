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
        
        guard let storedOrNewPdf = pdfEditable.getStoredOrNewPdf(context: self.pdfManagedContext) else {
            throw SaveError.unknownError
        }
        
        try self.saveChanges()
        
        // Must get the PdfEditable entity after having saved, because its ObjectId changes after having saved the object.
        guard let updatedPdfEditable = PdfEditable.create(withPdf: storedOrNewPdf) else {
            throw SaveError.unknownError
        }
        
        return updatedPdfEditable
    }
    
    func getDoPdfExist() throws -> Bool {
        var result = false
        let request = Pdf.fetchRequest()
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
        let fetchRequest = Pdf.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        do {
            return try self.persistence.container.viewContext
                .fetch(fetchRequest)
                .map { pdf in
                    guard let pdfEditable = PdfEditable.create(withPdf: pdf) else {
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
        guard let storedPdf = pdfEditable.getStoredPdf(context: self.pdfManagedContext) else {
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
    
    func getStoredOrNewPdf(context: NSManagedObjectContext) -> Pdf? {
        guard let pdfData = self.rawData else {
            debugPrint(for: self, message: "Cannot get pdf raw data for given PdfEditable instance")
            return nil
        }
        
        if let objectId = self.storeId {
            guard let pdf = (try? context.existingObject(with: objectId)) as? Pdf else {
                debugPrint(for: self, message: "Cannot found expected pdf for given object id")
                return nil
            }
            pdf.creationDate = self.creationDate
            pdf.data = pdfData
            pdf.password = self.password
            return pdf
        } else {
            return Pdf(context: context, pdfData: pdfData, password: self.password, creationDate: self.creationDate ?? Date())
        }
    }
    
    func getStoredPdf(context: NSManagedObjectContext) -> Pdf? {
        if let objectId = self.storeId {
            return (try? context.existingObject(with: objectId)) as? Pdf
        } else {
            return nil
        }
    }
    
    static func create(withPdf pdf: Pdf) -> Self? {
        guard let pdfDocument = pdf.pdfDocument else {
            debugPrint(for: self, message: "Cannot get pdf document for given Pdf instance")
            return nil
        }
        return PdfEditable(storeId: pdf.objectID, pdfDocument: pdfDocument, password: pdf.password, creationDate: pdf.creationDate)
    }
}
