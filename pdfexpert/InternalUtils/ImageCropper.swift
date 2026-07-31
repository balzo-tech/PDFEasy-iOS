//
//  ImageCropper.swift
//  MantisSwiftUIExample
//
//  Created by Yingtao Guo on 2/16/23.
//
//  The crop used to be handed back by writing into a binding and dismissing in the
//  same breath, which left the two racing: whoever presenting the cropper listened
//  through that binding could be told after it had already given up. It now says
//  what happened — cropped, or cancelled — and lets the caller decide what to close.
//

import Mantis
import SwiftUI

enum ImageCropperType {
    case normal
    case noRotaionDial
}

struct ImageCropper: UIViewControllerRepresentable {

    let image: UIImage
    let cropShapeType: Mantis.CropShapeType
    let presetFixedRatioType: Mantis.PresetFixedRatioType
    let type: ImageCropperType
    let onCrop: (UIImage) -> ()
    let onCancel: () -> ()

    class Coordinator: CropViewControllerDelegate {
        /// Kept up to date from `updateUIViewController`: the coordinator is made
        /// once and the view around it is remade often, so the copy taken here
        /// would otherwise be the one from the first pass.
        var parent: ImageCropper

        init(_ parent: ImageCropper) {
            self.parent = parent
        }

        func cropViewControllerDidCrop(_ cropViewController: Mantis.CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
            self.parent.onCrop(cropped)
        }

        func cropViewControllerDidCancel(_ cropViewController: Mantis.CropViewController, original: UIImage) {
            self.parent.onCancel()
        }

        /// Mantis could not produce a crop. Nothing came back, so this is a
        /// cancellation as far as everyone else is concerned — the alternative is
        /// a cropper that stays on screen with no way out.
        func cropViewControllerDidFailToCrop(_ cropViewController: Mantis.CropViewController, original: UIImage) {
            self.parent.onCancel()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        switch type {
        case .normal:
            return makeNormalImageCropper(context: context)
        case .noRotaionDial:
            return makeImageCropperHiddingRotationDial(context: context)
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self
    }
}

extension ImageCropper {
    func makeNormalImageCropper(context: Context) -> UIViewController {
        var config = Mantis.Config()
        config.cropViewConfig.cropShapeType = cropShapeType
        config.presetFixedRatioType = presetFixedRatioType
        let cropViewController = Mantis.cropViewController(image: image,
                                                           config: config)
        cropViewController.delegate = context.coordinator
        return cropViewController
    }

    func makeImageCropperHiddingRotationDial(context: Context) -> UIViewController {
        var config = Mantis.Config()
        config.cropViewConfig.showAttachedRotationControlView = false
        let cropViewController = Mantis.cropViewController(image: image, config: config)
        cropViewController.delegate = context.coordinator

        return cropViewController
    }
}
