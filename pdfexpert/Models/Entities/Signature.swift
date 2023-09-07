//
//  Signature.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/08/23.
//

import Foundation
import CoreData
import PencilKit

struct Signature {
    let id: UUID = UUID()
    private(set) var storeId: NSManagedObjectID? = nil
    let image: UIImage
    let creationDate: Date
    
    var rawData: Data? {
        return self.image.pngData()
    }
    
    init?(storeId: NSManagedObjectID,
         creationDate: Date?,
         data: Data) {
        guard let image = UIImage(data: data) else {
            return nil
        }
        print("Signature - On Load Image Size: \(image.size). Scale: \(image.scale)")
        self.storeId = storeId
        self.image = image
        self.creationDate = creationDate ?? Date()
    }
    
    init(image: UIImage) {
        print("Signature - On Save Image Size: \(image.size). Scale: \(image.scale)")
        self.image = image
        self.creationDate = Date()
    }
    
    mutating func updateStoreId(_ storeId: NSManagedObjectID?) {
        self.storeId = storeId
    }
}

extension Signature: Identifiable {}

extension PKDrawing {
    var signatureImage: UIImage {
        self.image(from: self.bounds, scale: K.Misc.SignatureDrawScaleFactor, userInterfaceStyle: .light)
    }
}
