//
//  Tag+Persistable.swift
//  PdfExpert
//

import Foundation
import CoreData

extension Tag: Persistable {

    typealias CDEntity = CDTag

    func getSavedOrNewCoreDataEntity(context: NSManagedObjectContext) -> CDEntity? {
        let result: CDTag = self.getSavedCoreDataEntity(context: context) ?? CDTag(context: context)
        result.update(withTag: self)
        return result
    }

    static func create(withCoreDataEntity coreDataEntity: some CDEntity) -> Self? {
        guard let name = coreDataEntity.name, !name.isEmpty else {
            debugPrint(for: self, message: "Skipping a CDTag with no name")
            return nil
        }
        return Tag(storeId: coreDataEntity.objectID,
                   name: name,
                   color: ArchiveColor.from(rawValue: coreDataEntity.colorIndex),
                   creationDate: coreDataEntity.creationDate ?? Date())
    }

    static func fetchRequest() -> NSFetchRequest<CDTag> {
        return NSFetchRequest<CDTag>(entityName: "Tag")
    }
}
