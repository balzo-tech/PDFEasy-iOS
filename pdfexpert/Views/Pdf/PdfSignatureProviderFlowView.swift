//
//  PdfSignatureProviderFlowView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/08/23.
//

import SwiftUI
import Factory

struct PdfSignatureProviderFlowView: ViewModifier {
    
    @ObservedObject var flow: PdfSignaturePrioviderFlow

    func body(content: Content) -> some View {
        content
            .formSheet(isPresented: self.$flow.showSignatureCreation,
                       size: CGSize(width: 400, height: 385)) {
                PdfSignatureCanvasView(viewModel: Container.shared.pdfSignatureCanvasViewModel({
                    self.flow.onSignatureSelected(signature: $0)
                }))
                .background(ColorPalette.primaryText)
            }.formSheet(isPresented: self.$flow.showSignaturePicker,
                        size: CGSize(width: 400, height: 700)) {
                let params = PdfSignaturePickerViewModel.Params(confirmationCallback: {
                    self.flow.onSignatureSelected(signature: $0)
                }, cancelCallback: {
                    self.flow.showSignaturePicker = false
                }, createNewSignatureCallback: {
                    self.flow.onCreateNewSignature()
                })
                PdfSignaturePickerView(viewModel: Container.shared.pdfSignaturePickerViewModel(params))
                    .background(ColorPalette.primaryText)
            }
    }
}

extension View {
    func pdfSignatureProviderView(flow: PdfSignaturePrioviderFlow) -> some View {
        self.modifier(PdfSignatureProviderFlowView(flow: flow))
    }
}
