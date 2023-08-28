//
//  CDSignature.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/08/23.
//

import Foundation
import CoreData

@objc(CDSignature)
public class CDSignature: NSManagedObject {
    
    func update(withSignature signature: Signature, imageData: Data) {
        self.data = imageData
        self.creationDate = signature.creationDate
    }
}

extension CDSignature {
    @NSManaged public var data: Data?
    @NSManaged public var creationDate: Date?
}
