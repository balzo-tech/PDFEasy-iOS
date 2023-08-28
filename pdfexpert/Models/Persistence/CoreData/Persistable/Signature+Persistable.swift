//
//  Signature+Persistable.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/08/23.
//

import Foundation
import CoreData

extension Signature: Persistable {
    
    typealias CDEntity = CDSignature
    
    func getSavedOrNewCoreDataEntity(context: NSManagedObjectContext) -> CDEntity? {
        
        guard let signatureData = self.rawData else {
            debugPrint(for: self, message: "Cannot get signature raw data for given Signature instance")
            return nil
        }
        
        let result: CDSignature = self.getSavedCoreDataEntity(context: context) ?? CDSignature(context: context)
        result.update(withSignature: self, imageData: signatureData)
        return result
    }
    
    static func create(withCoreDataEntity coreDataEntity: some CDEntity) -> Self? {
        
        guard let signatureData = coreDataEntity.data else {
            debugPrint(for: self, message: "Cannot get signature data for given CDSignature instance")
            return nil
        }
        let signature = try? Signature(storeId: coreDataEntity.objectID,
                                       creationDate: coreDataEntity.creationDate,
                                       data: signatureData
        )
        guard let signature else {
            debugPrint(for: self, message: "Cannot get signature drawing for given signature data")
            return nil
        }
        return signature
    }
    
    static func fetchRequest() -> NSFetchRequest<CDSignature> {
        return NSFetchRequest<CDSignature>(entityName: "Signature")
    }
}
