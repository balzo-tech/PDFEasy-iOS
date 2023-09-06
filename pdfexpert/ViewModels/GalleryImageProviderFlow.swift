//
//  GalleryImageProviderFlow.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/09/23.
//

import Foundation
import Factory
import PhotosUI
import UIKit
import SwiftUI

extension Container {
    var galleryImageProviderFlow: Factory<GalleryImageProviderFlow> {
        self { GalleryImageProviderFlow() }
    }
}

class GalleryImageProviderFlow: ObservableObject {
    
    typealias GalleryImageSelectedCallback = ((UIImage) -> ())
    
    @Published var asyncImageLoading: AsyncEmptyFailable<SharedUnderlyingError> = .idle
    @Published var imagePickerShow: Bool = false
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet {
            if let imageSelection {
                let progress = self.loadTransferable(from: imageSelection)
                self.asyncImageLoading = .loading(progress)
            } else {
                self.asyncImageLoading = .idle
            }
        }
    }
    
    private var onImageSelected: GalleryImageSelectedCallback?
    
    func startFlow(onImageSelected: @escaping GalleryImageSelectedCallback) {
        self.onImageSelected = onImageSelected
        self.imagePickerShow = true
    }
    
    private func loadTransferable(from imageSelection: PhotosPickerItem) -> Progress {
        return imageSelection.loadTransferable(type: PickedImage.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image?):
                    self.asyncImageLoading = .idle
                    self.onImageSelected?(image.uiImage)
                case .success(nil):
                    self.asyncImageLoading = .idle
                case .failure(let error):
                    self.asyncImageLoading = .error(SharedUnderlyingError.convertError(fromError: error))
                }
            }
        }
    }
}
