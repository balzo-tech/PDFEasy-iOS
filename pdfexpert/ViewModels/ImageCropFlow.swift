//
//  ImageCropFlow.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/09/23.
//
//  Presents Mantis over an image and hands back what the user kept.
//
//  Two reports came from this file, and both were about *when* things happen rather
//  than about cropping. A signature taken from the photo library or the camera first
//  never got as far as the cropper, and then reached it and came back empty.
//
//  1. The cropper is a `fullScreenCover` on the *same* view that has just shown the
//     photo picker or the camera, and the image arrives while that one is still
//     closing. SwiftUI drops a presentation asked for during another's dismissal,
//     and since `cropperShow` was already `true` nothing ever asked again — the flow
//     was stuck for good, not just that once. It is asked for once the screen is
//     free, and if it was dropped anyway the cover says so by never appearing, which
//     is the cue to ask again.
//  2. The crop itself used to come back through `image` — the very property the
//     source image goes in by — and be delivered from its `didSet`, while the
//     cover's `onDisappear` raced to throw the callback away. Mantis now tells this
//     flow what happened, and this flow closes the cover: no binding in the middle,
//     no order to get right.
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
    private let presentationSettleDelay: TimeInterval
    /// How long the cover is given to appear before its silence is taken as a
    /// dropped presentation.
    private let presentationCheckDelay: TimeInterval
    /// A dropped presentation is worth retrying, an unpresentable one is not.
    private static let maxPresentationAttempts: Int = 4

    @Published var cropperShow: Bool = false
    @Published private(set) var image: UIImage? = nil
    @Published var cropShapeType: Mantis.CropShapeType = .rect
    @Published var presetFixedRatioType: Mantis.PresetFixedRatioType = .canUseMultiplePresetFixedRatio()
    @Published var type: ImageCropperType = .normal

    private var onImageCropped: ImageCroppedCallback? = nil
    /// Set by the cover itself when it comes on screen. Its absence is the only
    /// honest sign that SwiftUI never presented what was asked for.
    private var cropperDidAppear: Bool = false

    init(presentationSettleDelay: TimeInterval = 0.45,
         presentationCheckDelay: TimeInterval = 0.6) {
        self.presentationSettleDelay = presentationSettleDelay
        self.presentationCheckDelay = presentationCheckDelay
    }

    func startFlow(
        image: UIImage,
        cropShapeType: Mantis.CropShapeType = .rect,
        presetFixedRatioType: Mantis.PresetFixedRatioType = .canUseMultiplePresetFixedRatio(),
        type: ImageCropperType = .normal,
        onImageCropped: @escaping ImageCroppedCallback
    ) {
        self.image = image
        self.cropShapeType = cropShapeType
        self.presetFixedRatioType = presetFixedRatioType
        self.type = type
        self.onImageCropped = onImageCropped
        self.cropperDidAppear = false
        self.presentCropper(attempt: 0)
    }

    /// The cropper is on screen. Nothing to do but stop expecting it.
    func onCropViewAppeared() {
        self.cropperDidAppear = true
    }

    /// The user kept a crop. The cover is closed from here rather than from inside
    /// it, so the image is already delivered by the time anything goes away.
    func onCropConfirmed(image: UIImage) {
        let onImageCropped = self.onImageCropped
        self.onImageCropped = nil
        self.cropperShow = false
        onImageCropped?(image)
    }

    /// The user left the cropper without keeping anything. Nobody is told, and
    /// nothing stays armed behind it.
    func onCropCancelled() {
        self.onImageCropped = nil
        self.cropperShow = false
    }

    /// Asks for the cover once whatever presented us has finished leaving the
    /// screen, and asks again if it never arrived. `cropperShow` goes back to
    /// `false` first: SwiftUI only presents on the change, so a flag left `true`
    /// by a dropped presentation is a flow that can never start again.
    private func presentCropper(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + self.presentationSettleDelay) { [weak self] in
            guard let self, self.onImageCropped != nil else { return }
            self.cropperShow = true
            DispatchQueue.main.asyncAfter(deadline: .now() + self.presentationCheckDelay) { [weak self] in
                guard let self,
                      !self.cropperDidAppear,
                      self.onImageCropped != nil,
                      attempt + 1 < Self.maxPresentationAttempts else { return }
                self.cropperShow = false
                self.presentCropper(attempt: attempt + 1)
            }
        }
    }
}
