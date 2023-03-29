//
//  ImageManagerImpl.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import Photos
import UIKit

class ImageManagerImpl: NSObject, ImageManager {
    
    var saveSuccess: PhotoAddSuccess?
    var saveFailed: PhotoAddFail?
    
    func savePhotoInLibrary(uiImage: UIImage, saveSuccess: @escaping PhotoAddSuccess, saveFailed: @escaping PhotoAddFail) {
        self.saveSuccess = saveSuccess
        self.saveFailed = saveFailed
        var image = uiImage
        if let ciImage = image.ciImage {
            let context = CIContext()
            let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
            image = UIImage(cgImage: cgImage)
        }
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
        
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Save image failed with error: \(error)")
            saveFailed?(error)
        } else {
            print("Save image successful")
            saveSuccess?()
        }
    }
}
