//
//  Folder.swift
//  PdfExpert
//
//  Folders are flat by design: a document belongs to one folder or to none.
//  Anything that needs to cut across folders is what tags are for.
//

import Foundation
import CoreData

struct Folder: Hashable, Identifiable {

    private(set) var storeId: NSManagedObjectID? = nil
    var name: String
    var color: ArchiveColor
    private(set) var creationDate: Date

    init(storeId: NSManagedObjectID? = nil,
         name: String,
         color: ArchiveColor = .blue,
         creationDate: Date = Date()) {
        self.storeId = storeId
        self.name = name
        self.color = color
        self.creationDate = creationDate
    }

    /// Stable across a refresh: the same folder keeps its identity while the
    /// list is re-fetched, so SwiftUI does not re-create the row.
    var id: String {
        self.storeId?.uriRepresentation().absoluteString ?? "new-\(self.name)"
    }

    mutating func updateStoreId(_ storeId: NSManagedObjectID?) {
        self.storeId = storeId
    }
}
