//
//  ImageCropFlow.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/09/23.
//
//  Presents Mantis over an image and hands back what the user kept.
//
//  Two things here are less obvious than they look, and both come from the same
//  report: a signature taken from the photo library or the camera never appeared,
//  the picker opened and then the sheet came back empty.
//
//  1. The cropper is a `fullScreenCover` on the *same* view that has just shown the
//     photo picker or the camera, and the image arrives while that one is still
//     closing. SwiftUI drops a presentation asked for during another's dismissal,
//     and since `cropperShow` was already `true` nothing ever asked again — the
//     flow was stuck for good, not just that once.
//  2. `image` is both the way in and the way out (the cropper writes back through
//     the binding), so the incoming image used to fire the "cropped" path on its
//     way through.
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

    typealias ImageCroppedCallback = ((UIImage) -> ())

    /// Long enough for a sheet or a cover to finish going away. A presentation
    /// asked for before that is silently dropped.
    private static let presentationSettleDelay: TimeInterval = 0.45

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
    /// True while the image being assigned is the one going *in*, so the callback
    /// is not called with it.
    private var isLoadingSource: Bool = false

    func startFlow(
        image: UIImage,
        cropShapeType: Mantis.CropShapeType = .rect,
        presetFixedRatioType: Mantis.PresetFixedRatioType = .canUseMultiplePresetFixedRatio(),
        type: ImageCropperType = .normal,
        onImageCropped: @escaping ImageCroppedCallback
    ) {
        self.isLoadingSource = true
        self.image = image
        self.isLoadingSource = false
        self.cropShapeType = cropShapeType
        self.presetFixedRatioType = presetFixedRatioType
        self.type = type
        self.onImageCropped = onImageCropped
        // Asked for after whatever presented us has finished leaving the screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.presentationSettleDelay) { [weak self] in
            self?.cropperShow = true
        }
    }

    func onCropViewDismiss() {
        self.onCropCompleted(image: nil)
    }

    private func onCropCompleted(image: UIImage?) {
        guard !self.isLoadingSource else { return }
        if let image {
            self.onImageCropped?(image)
        }
        self.onImageCropped = nil
    }
}
