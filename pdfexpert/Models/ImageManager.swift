//
//  ImageManager.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 03/03/23.
//

import Foundation
import Factory
import UIKit

protocol ImageManager {
    
    typealias PhotoAddSuccess = (() -> ())
    typealias PhotoAddFail = ((Error) -> ())
    
    func savePhotoInLibrary(uiImage: UIImage, saveSuccess: @escaping PhotoAddSuccess, saveFailed: @escaping PhotoAddFail)
}

extension Container {
    var imageManager: Factory<ImageManager> {
        self { ImageManagerImpl() }.singleton
    }
}
