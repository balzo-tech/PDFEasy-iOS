//
//  ImageCropFlowView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/09/23.
//

import SwiftUI
import Mantis

struct ImageCropFlowView: ViewModifier {

    @ObservedObject var flow: ImageCropFlow

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: self.$flow.cropperShow) {
                // Nothing to crop should not be possible — the flow only asks for
                // the cover once it has an image — but a cover that force-unwraps
                // its way to a crash is not worth the shorter line.
                if let image = self.flow.image {
                    ImageCropper(image: image,
                                 cropShapeType: self.flow.cropShapeType,
                                 presetFixedRatioType: self.flow.presetFixedRatioType,
                                 type: self.flow.type,
                                 onCrop: { self.flow.onCropConfirmed(image: $0) },
                                 onCancel: self.flow.onCropCancelled)
                    // The flow presents this cover on a timer, because it is asked
                    // for while the picker that produced the image is still going
                    // away. This is how it learns that the wait was long enough.
                    .onAppear(perform: self.flow.onCropViewAppeared)
                    .ignoresSafeArea()
                }
            }
    }
}

extension View {
    func imageCropView(flow: ImageCropFlow) -> some View {
        self.modifier(ImageCropFlowView(flow: flow))
    }
}
