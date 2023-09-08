//
//  SuggestedFields+Persistable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 07/09/23.
//

import Foundation
import CoreData

extension SuggestedFields: Persistable {
    
    typealias CDEntity = CDSuggestedFields
    
    func getSavedOrNewCoreDataEntity(context: NSManagedObjectContext) -> CDEntity? {
        let result: CDEntity = self.getSavedCoreDataEntity(context: context) ?? CDEntity(context: context)
        result.update(withSuggestedFields: self)
        return result
    }
    
    static func create(withCoreDataEntity coreDataEntity: some CDEntity) -> Self? {
        
        return SuggestedFields(
            storeId: coreDataEntity.objectID,
            firstName: coreDataEntity.firstName,
            lastName: coreDataEntity.lastName
        )
    }
    
    static func fetchRequest() -> NSFetchRequest<CDEntity> {
        return NSFetchRequest<CDEntity>(entityName: "SuggestedFields")
    }
}
