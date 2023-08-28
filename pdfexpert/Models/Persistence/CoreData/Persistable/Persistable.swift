//
//  Persistable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/08/23.
//

import Foundation
import CoreData

protocol Persistable {
    
    associatedtype CDEntity: NSManagedObject
    
    var storeId: NSManagedObjectID? { get }
    
    static func create(withCoreDataEntity coreDataEntity: CDEntity) -> Self?
    static func fetchRequest() -> NSFetchRequest<CDEntity>
    
    func getSavedOrNewCoreDataEntity(context: NSManagedObjectContext) -> CDEntity?
}

extension Persistable {
    func getSavedCoreDataEntity(context: NSManagedObjectContext) -> CDEntity? {
        if let objectId = self.storeId {
            return (try? context.existingObject(with: objectId)) as? CDEntity
        } else {
            return nil
        }
    }
}
