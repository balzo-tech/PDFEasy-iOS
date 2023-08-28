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
import PencilKit

private let DiskFullErrorDomain: String = NSSQLiteErrorDomain
private let DiskFullErrorCode: Int = 13

extension Container {
    var repository: Factory<Repository> {
        self { RepositoryImpl() }.singleton
    }
}

class RepositoryImpl: Repository {
    
    @Injected(\.persistence) var persistence
    @Injected(\.analyticsManager) var analyticsMananger
    
    private var sharedManagedContext: NSManagedObjectContext {
        return self.persistence.container.viewContext
    }
    
    // MARK: - PDF
    
    func savePdf(pdf: Pdf) throws -> Pdf {
        
        guard let savedOrNewPdf = pdf.getSavedOrNewPdf(context: self.sharedManagedContext) else {
            throw SaveError.unknownError
        }
        
        try self.saveChanges()
        
        // Must get the Pdf entity after having saved, because its ObjectId changes after having saved the object.
        guard let updatedPdf = Pdf.create(withCoreDataPdf: savedOrNewPdf) else {
            throw SaveError.unknownError
        }
        
        self.analyticsMananger.track(event: .pdfSaved)
        
        return updatedPdf
    }
    
    func getDoPdfExist() throws -> Bool {
        var result = false
        let request = CDPdf.fetchRequest()
        request.includesSubentities = false
        do {
            result = try self.persistence.container
                .viewContext.fetch(request).count > 0
        } catch {
            debugPrint(for: self, message: "Error while fetching pdfs")
            throw SharedUnderlyingError.convertError(fromError: error)
        }
        return result
    }
    
    func loadPdfs() throws -> [Pdf] {
        let fetchRequest = CDPdf.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        do {
            return try self.persistence.container.viewContext
                .fetch(fetchRequest)
                .map { pdf in
                    guard let pdf = Pdf.create(withCoreDataPdf: pdf) else {
                        throw SharedUnderlyingError.unknownError
                    }
                    return pdf
            }
        } catch {
            debugPrint(for: self, message: "Error while fetching pdfs")
            throw SharedUnderlyingError.convertError(fromError: error)
        }
    }
    
    func delete(pdf: Pdf) throws {
        guard let storedPdf = pdf.getSavedPdf(context: self.sharedManagedContext) else {
            debugPrint(for: self, message: "Current Pdf instance doesn't exist in the persistent storage")
            return
        }
        self.persistence.container.viewContext.delete(storedPdf)
        try self.saveChanges()
    }
    
    // MARK: - Signature
    
    func saveSignature(signature: Signature) throws -> Signature {
        
        guard let savedOrNewSignature = signature.getSavedOrNewSignature(context: self.sharedManagedContext) else {
            throw SaveError.unknownError
        }
        
        try self.saveChanges()
        
        // Must get the Signature entity after having saved, because its ObjectId changes after having saved the object.
        guard let updatedSignature = Signature.create(withCoreDataSignature: savedOrNewSignature) else {
            throw SaveError.unknownError
        }
        
        self.analyticsMananger.track(event: .signatureFileSaved)
        
        return updatedSignature
    }
    
    func getDoSignatureExist() throws -> Bool {
        var result = false
        let request = CDSignature.fetchRequest()
        request.includesSubentities = false
        do {
            result = try self.persistence.container
                .viewContext.fetch(request).count > 0
        } catch {
            debugPrint(for: self, message: "Error while fetching signatures")
            throw SharedUnderlyingError.convertError(fromError: error)
        }
        return result
    }
    
    func loadSignatures() throws -> [Signature] {
        let fetchRequest = CDSignature.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        do {
            return try self.persistence.container.viewContext
                .fetch(fetchRequest)
                .map { signature in
                    guard let signature = Signature.create(withCoreDataSignature: signature) else {
                        throw SharedUnderlyingError.unknownError
                    }
                    return signature
            }
        } catch {
            debugPrint(for: self, message: "Error while fetching signatures")
            throw SharedUnderlyingError.convertError(fromError: error)
        }
    }
    
    func delete(signature: Signature) throws {
        guard let storedSignature = signature.getSavedSignature(context: self.sharedManagedContext) else {
            debugPrint(for: self, message: "Current Signature instance doesn't exist in the persistent storage")
            return
        }
        self.persistence.container.viewContext.delete(storedSignature)
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

fileprivate extension Pdf {
    
    func getSavedOrNewPdf(context: NSManagedObjectContext) -> CDPdf? {
        
        guard let pdfData = self.rawData else {
            debugPrint(for: self, message: "Cannot get pdf raw data for given Pdf instance")
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
        return Pdf(storeId: pdf.objectID,
                           pdfDocument: pdfDocument,
                           password: pdf.password,
                           creationDate: pdf.creationDate,
                           fileName: pdf.filename,
                           compression: CompressionOption(rawValue: pdf.compression) ?? K.Misc.PdfDefaultCompression,
                           margins: MarginsOption(rawValue: pdf.margins) ?? K.Misc.PdfDefaultMarginsOption)
    }
}

fileprivate extension Signature {
    
    func getSavedOrNewSignature(context: NSManagedObjectContext) -> CDSignature? {
        
        guard let signatureData = self.rawData else {
            debugPrint(for: self, message: "Cannot get signature raw data for given Signature instance")
            return nil
        }
        
        var result: CDSignature? = nil
        
        if let objectId = self.storeId {
            guard let savedSignature = (try? context.existingObject(with: objectId)) as? CDSignature else {
                debugPrint(for: self, message: "Cannot found expected CDSignature instance for given object id")
                return nil
            }
            result = savedSignature
        } else {
            result = CDSignature(context: context)
        }
        
        result?.update(withSignature: self, imageData: signatureData)
        
        return result
    }
    
    func getSavedSignature(context: NSManagedObjectContext) -> CDSignature? {
        if let objectId = self.storeId {
            return (try? context.existingObject(with: objectId)) as? CDSignature
        } else {
            return nil
        }
    }
    
    static func create(withCoreDataSignature coreDataSignature: CDSignature) -> Self? {
        guard let signatureData = coreDataSignature.data else {
            debugPrint(for: self, message: "Cannot get signature data for given CDSignature instance")
            return nil
        }
        let signature = try? Signature(storeId: coreDataSignature.objectID,
                                       creationDate: coreDataSignature.creationDate,
                                       data: signatureData
        )
        guard let signature else {
            debugPrint(for: self, message: "Cannot get signature drawing for given signature data")
            return nil
        }
        return signature
    }
}
