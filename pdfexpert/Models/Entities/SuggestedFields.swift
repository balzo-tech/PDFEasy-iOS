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
    
    var fields: [String] {
        let fields: [String?] = [
            self.firstName,
            self.lastName
        ]
        return fields.compactMap { $0 }
    }

    mutating func updateStoreId(_ storeId: NSManagedObjectID?) {
        self.storeId = storeId
    }
}
