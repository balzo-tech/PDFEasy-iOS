//
//  CDSuggestedFields.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 07/09/23.
//

import Foundation
import CoreData

@objc(CDSuggestedFields)
public class CDSuggestedFields: NSManagedObject {
    
    func update(withSuggestedFields suggestedFields: SuggestedFields) {
        self.firstName = suggestedFields.firstName
        self.lastName = suggestedFields.lastName
    }
}

extension CDSuggestedFields {
    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
}
