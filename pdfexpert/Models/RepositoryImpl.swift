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
    
    var pdfManagedContext: NSManagedObjectContext {
        return self.persistence.container.viewContext
    }
    
    func saveChanges() throws {
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
    
    func getDoPdfExist() throws -> Bool {
        var result = false
        let request = Pdf.fetchRequest()
        request.includesSubentities = false
        do {
            result = try self.persistence.container
                .viewContext.fetch(request).count > 0
        } catch {
            debugPrint(for: self, message: "Error while fetching stories")
            throw LoadError.convertError(fromError: error)
        }
        return result
    }
    
    func loadPdfs() throws -> [Pdf] {
        let fetchRequest = Pdf.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        do {
            return try self.persistence.container.viewContext.fetch(fetchRequest)
        } catch {
            debugPrint(for: self, message: "Error while fetching stories")
            throw LoadError.convertError(fromError: error)
        }
    }
    
    func delete(pdf: Pdf) {
        self.persistence.container.viewContext.delete(pdf)
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

enum LoadError: UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
}
