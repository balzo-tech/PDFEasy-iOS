//
//  CameraImageProviderFlowView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/09/23.
//

import SwiftUI
import Factory

struct CameraImageProviderFlowView: ViewModifier {
    
    @ObservedObject var flow: CameraImageProviderFlow

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: self.$flow.cameraShow) {
                CameraView(model: Container.shared.cameraViewModel({ uiImage in
                    self.flow.onPhotoCaptured(image: uiImage)
                }))
            }
    }
}

extension View {
    func cameraImageProviderView(flow: CameraImageProviderFlow) -> some View {
        self.modifier(CameraImageProviderFlowView(flow: flow))
    }
}
