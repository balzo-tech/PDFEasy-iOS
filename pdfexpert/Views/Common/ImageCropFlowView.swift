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
                ImageCropper(image: self.$flow.image,
                             cropShapeType: self.$flow.cropShapeType,
                             presetFixedRatioType: self.$flow.presetFixedRatioType,
                             type: self.$flow.type)
                .onDisappear(perform: self.flow.onCropViewDismiss)
                .ignoresSafeArea()
            }
    }
}

extension View {
    func imageCropView(flow: ImageCropFlow) -> some View {
        self.modifier(ImageCropFlowView(flow: flow))
    }
}
