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
    let drawing: PKDrawing
    let creationDate: Date
    
    var rawData: Data? {
        return self.drawing.dataRepresentation()
    }
    
    var image: UIImage {
        self.drawing.signatureImage
    }
    
    init(storeId: NSManagedObjectID,
         creationDate: Date?,
         data: Data) throws {
        self.storeId = storeId
        self.drawing = try PKDrawing(data: data)
        self.creationDate = creationDate ?? Date()
    }
    
    init(drawing: PKDrawing) {
        self.drawing = drawing
        self.creationDate = Date()
    }
    
    mutating func updateStoreId(_ storeId: NSManagedObjectID?) {
        self.storeId = storeId
    }
}

extension Signature: Identifiable {}

extension PKDrawing {
    var signatureImage: UIImage {
        self.image(from: CGRect(origin: .zero, size: K.Misc.SignatureSize), scale: 1.0, userInterfaceStyle: .light)
    }
}
