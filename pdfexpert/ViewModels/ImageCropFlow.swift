//
//  ImageCropFlow.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/09/23.
//

import Foundation
import Factory
import UIKit
import Mantis

extension Container {
    var imageCropFlow: Factory<ImageCropFlow> {
        self { ImageCropFlow() }
    }
}

class ImageCropFlow: ObservableObject {
    
    typealias ImageCroppedCallback = ((UIImage?) -> ())
    
    @Published var cropperShow: Bool = false
    @Published var image: UIImage? = nil {
        didSet {
            self.onCropCompleted(image: image)
        }
    }
    @Published var cropShapeType: Mantis.CropShapeType = .rect
    @Published var presetFixedRatioType: Mantis.PresetFixedRatioType = .canUseMultiplePresetFixedRatio()
    @Published var type: ImageCropperType = .normal
    
    private var onImageCropped: ImageCroppedCallback? = nil
    
    func startFlow(
        image: UIImage,
        cropShapeType: Mantis.CropShapeType = .rect,
        presetFixedRatioType: Mantis.PresetFixedRatioType = .canUseMultiplePresetFixedRatio(),
        type: ImageCropperType = .normal,
        onImageCropped: @escaping ImageCroppedCallback
    ) {
        self.cropperShow = true
        self.image = image
        self.cropShapeType = cropShapeType
        self.presetFixedRatioType = presetFixedRatioType
        self.type = type
        self.onImageCropped = onImageCropped
    }
    
    func onCropViewDismiss() {
        self.onCropCompleted(image: nil)
    }
    
    private func onCropCompleted(image: UIImage?) {
        self.onImageCropped?(image)
        self.onImageCropped = nil
    }
}
