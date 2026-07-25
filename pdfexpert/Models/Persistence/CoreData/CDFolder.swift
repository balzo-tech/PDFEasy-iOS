//
//  CDFolder.swift
//  PdfExpert
//
//  A folder the user files documents into. `pdfs` is the inverse of
//  `CDPdf.folder`; deleting a folder nullifies it, so the documents survive and
//  fall back to "Unfiled".
//

import Foundation
import CoreData

@objc(CDFolder)
public class CDFolder: NSManagedObject {

    func update(withFolder folder: Folder) {
        self.name = folder.name
        self.colorIndex = folder.color.rawValue
        self.creationDate = folder.creationDate
    }
}

extension CDFolder {
    @NSManaged public var name: String?
    @NSManaged public var colorIndex: Int32
    @NSManaged public var creationDate: Date?
    @NSManaged public var pdfs: NSSet?
}
