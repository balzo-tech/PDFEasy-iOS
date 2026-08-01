//
//  PdfSignatureProviderFlowView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/08/23.
//

import SwiftUI
import Factory

struct PdfSignatureProviderFlowView: ViewModifier {

    /// The creation sheet is a form sheet on an iPad and a detent-height sheet
    /// on a phone, so its size is also the phone's detent — hence two of them.
    /// The iPad one is deliberately generous: signing with a Pencil in a 385pt
    /// box produces an initial, not a signature.
    private static var signatureCreationSize: CGSize {
        UIDevice.hasDesktopClassLayout
            ? CGSize(width: 620, height: 560)
            : CGSize(width: 400, height: 385)
    }

    @ObservedObject var flow: PdfSignaturePrioviderFlow

    func body(content: Content) -> some View {
        content
            .formSheet(isPresented: self.$flow.showSignatureCreation,
                       size: Self.signatureCreationSize) {
                PdfSignatureCanvasView(viewModel: Container.shared.pdfSignatureCanvasViewModel({
                    self.flow.onSignatureSelected(signature: $0)
                }))
                .background(ColorPalette.signatureSheet)
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
                    .background(ColorPalette.signatureSheet)
            }
    }
}

extension View {
    func pdfSignatureProviderView(flow: PdfSignaturePrioviderFlow) -> some View {
        self.modifier(PdfSignatureProviderFlowView(flow: flow))
    }
}
