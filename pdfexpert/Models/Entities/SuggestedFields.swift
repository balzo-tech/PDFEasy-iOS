//
//  SuggestedFields.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 07/09/23.
//

import Foundation
import CoreData

struct SuggestedFields {
    private(set) var storeId: NSManagedObjectID? = nil
    var firstName: String?
    var lastName: String?
    var address: String?
    var city: String?
    var country: String?
    var email: String?
    var phone: String?
    
    var fields: [String] {
        let fields: [String?] = [
            self.firstName,
            self.lastName,
            self.address,
            self.city,
            self.country,
            self.email,
            self.phone
        ]
        return fields.compactMap { $0 }
    }

    mutating func updateStoreId(_ storeId: NSManagedObjectID?) {
        self.storeId = storeId
    }
}
