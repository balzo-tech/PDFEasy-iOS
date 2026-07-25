//
//  Tag.swift
//  PdfExpert
//
//  A tag can be on many documents and a document can carry many tags — the
//  cross-cutting counterpart to `Folder`.
//

import Foundation
import CoreData

struct Tag: Hashable, Identifiable {

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

    var id: String {
        self.storeId?.uriRepresentation().absoluteString ?? "new-\(self.name)"
    }

    mutating func updateStoreId(_ storeId: NSManagedObjectID?) {
        self.storeId = storeId
    }
}
