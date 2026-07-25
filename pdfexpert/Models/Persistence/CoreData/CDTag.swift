//
//  CDTag.swift
//  PdfExpert
//
//  A label that can be attached to any number of documents (and a document to
//  any number of labels): the many-to-many counterpart of `CDFolder`.
//

import Foundation
import CoreData

@objc(CDTag)
public class CDTag: NSManagedObject {

    func update(withTag tag: Tag) {
        self.name = tag.name
        self.colorIndex = tag.color.rawValue
        self.creationDate = tag.creationDate
    }
}

extension CDTag {
    @NSManaged public var name: String?
    @NSManaged public var colorIndex: Int32
    @NSManaged public var creationDate: Date?
    @NSManaged public var pdfs: NSSet?
}
