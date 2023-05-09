//
//  Pdf+CoreDataProperties.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//
//

import Foundation
import CoreData


extension Pdf {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Pdf> {
        return NSFetchRequest<Pdf>(entityName: "Pdf")
    }

    @NSManaged public var creationDate: Date?
    @NSManaged public var data: Data?
    @NSManaged public var password: String?

}

extension Pdf : Identifiable {

}
