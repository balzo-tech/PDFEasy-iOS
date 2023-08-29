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
    @Injected(\.analyticsManager) var analyticsMananger
    
    private var sharedManagedContext: NSManagedObjectContext {
        return self.persistence.container.viewContext
    }
    
    // MARK: - PDF
    
    func savePdf(pdf: Pdf) throws -> Pdf {
        let pdf = try self.save(pdf)
        self.analyticsMananger.track(event: .pdfSaved)
        return pdf
    }
    
    func getDoPdfExist() throws -> Bool {
        return try self.getDoExist(forPersistableType: Pdf.self)
    }
    
    func loadPdfs() throws -> [Pdf] {
        return try self.loadItems()
    }
    
    func delete(pdf: Pdf) throws {
        try self.delete(pdf)
        self.analyticsMananger.track(event: .existingPdfRemoved)
    }
    
    // MARK: - Signature
    
    func saveSignature(signature: Signature) throws -> Signature {
        let signature = try self.save(signature)
        self.analyticsMananger.track(event: .signatureFileSaved)
        return signature
    }
    
    func getDoSignatureExist() throws -> Bool {
        return try self.getDoExist(forPersistableType: Signature.self)
    }
    
    func loadSignatures() throws -> [Signature] {
        return try self.loadItems()
    }
    
    func delete(signature: Signature) throws {
        try self.delete(signature)
        self.analyticsMananger.track(event: .signatureFileDeleted)
    }
    
    func delete(signatures: [Signature]) throws {
        for signature in signatures {
            try self.delete(signature: signature)
        }
    }
    
    // MARK: - Private Methods
    
    private func save<T: Persistable>(_ persistable: T) throws -> T {
        
        guard let savedOrNewCoreDataEntity = persistable.getSavedOrNewCoreDataEntity(context: self.sharedManagedContext) else {
            throw SaveError.unknownError
        }
        
        try self.saveChanges()
        
        guard let updatedPersistable = T.create(withCoreDataEntity: savedOrNewCoreDataEntity) else {
            throw SaveError.unknownError
        }
        
        return updatedPersistable
    }
    
    private func getDoExist<T: Persistable>(forPersistableType type: T.Type) throws -> Bool {
        var result = false
        let request = T.fetchRequest()
        request.includesSubentities = false
        do {
            result = try self.persistence.container
                .viewContext.fetch(request).count > 0
        } catch {
            debugPrint(for: self, message: "Error while fetching items")
            throw SharedUnderlyingError.convertError(fromError: error)
        }
        return result
    }
    
    private func loadItems<T: Persistable>() throws -> [T] {
        let fetchRequest = T.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        do {
            return try self.persistence.container.viewContext
                .fetch(fetchRequest)
                .map { coreDataEntity in
                    guard let item = T.create(withCoreDataEntity: coreDataEntity) else {
                        throw SharedUnderlyingError.unknownError
                    }
                    return item
                }
        } catch {
            debugPrint(for: self, message: "Error while fetching items")
            throw SharedUnderlyingError.convertError(fromError: error)
        }
    }
    
    private func delete<T: Persistable>(_ persistable: T) throws {
        
        guard let storedSignature = persistable.getSavedCoreDataEntity(context: self.sharedManagedContext) else {
            debugPrint(for: self, message: "Current peristable instance doesn't exist in the persistent storage")
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
