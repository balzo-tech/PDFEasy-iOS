//
//  PickedImage.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 07/06/23.
//

import Foundation
import PhotosUI
import SwiftUI

struct PickedImage: Transferable {
    let uiImage: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
        #if canImport(UIKit)
            guard let uiImage = UIImage(data: data) else {
                throw ImageTransferError.importFailed
            }
            return PickedImage(uiImage: uiImage)
        #else
            throw ImageTransferError.importFailed
        #endif
        }
    }
}

enum ImageTransferError: LocalizedError {
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .importFailed: return "Couldn't import the selected photo."
        }
    }
}
