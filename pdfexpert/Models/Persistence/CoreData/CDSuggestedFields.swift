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
        self.address = suggestedFields.address
        self.city = suggestedFields.city
        self.country = suggestedFields.country
        self.email = suggestedFields.email
        self.phone = suggestedFields.phone
    }
}

extension CDSuggestedFields {
    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
    @NSManaged public var address: String?
    @NSManaged public var city: String?
    @NSManaged public var country: String?
    @NSManaged public var email: String?
    @NSManaged public var phone: String?
}
