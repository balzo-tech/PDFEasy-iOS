//
//  Folder+Persistable.swift
//  PdfExpert
//

import Foundation
import CoreData

extension Folder: Persistable {

    typealias CDEntity = CDFolder

    func getSavedOrNewCoreDataEntity(context: NSManagedObjectContext) -> CDEntity? {
        let result: CDFolder = self.getSavedCoreDataEntity(context: context) ?? CDFolder(context: context)
        result.update(withFolder: self)
        return result
    }

    static func create(withCoreDataEntity coreDataEntity: some CDEntity) -> Self? {
        // A folder without a name cannot be shown or picked; treat it as corrupt
        // rather than surfacing a blank chip.
        guard let name = coreDataEntity.name, !name.isEmpty else {
            debugPrint(for: self, message: "Skipping a CDFolder with no name")
            return nil
        }
        return Folder(storeId: coreDataEntity.objectID,
                      name: name,
                      color: ArchiveColor.from(rawValue: coreDataEntity.colorIndex),
                      creationDate: coreDataEntity.creationDate ?? Date())
    }

    static func fetchRequest() -> NSFetchRequest<CDFolder> {
        return NSFetchRequest<CDFolder>(entityName: "Folder")
    }
}
