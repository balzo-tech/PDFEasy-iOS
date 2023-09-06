//
//  GalleryImageProviderFlowView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/09/23.
//

import SwiftUI
import PhotosUI

struct GalleryImageProviderFlowView: ViewModifier {
    
    @ObservedObject var flow: GalleryImageProviderFlow

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: self.$flow.imagePickerShow,
                          selection: self.$flow.imageSelection,
                          matching: .images)
            .asyncFailableView(asyncItem: self.$flow.asyncImageLoading)
    }
}

extension View {
    func galleryImageProviderView(flow: GalleryImageProviderFlow) -> some View {
        self.modifier(GalleryImageProviderFlowView(flow: flow))
    }
}
