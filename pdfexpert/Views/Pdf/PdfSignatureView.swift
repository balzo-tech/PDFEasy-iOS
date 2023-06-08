//
//  PdfSignatureView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 10/05/23.
//

import SwiftUI
import Factory

struct PdfSignatureView: View {
    
    @StateObject var viewModel: PdfSignatureViewModel
    @Environment(\.dismiss) var dismiss
    @State var showCancelWarningDialog: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { geometryReader in
                    PdfKitViewBinder(
                        pdfView: self.$viewModel.pdfView,
                        singlePage: false,
                        pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0),
                        backgroundColor: UIColor(ColorPalette.primaryBG),
                        usePaginator: true
                    )
                    .onTapGesture { self.viewModel.tapOnPdfView() }
                }
                if let signatureImage = self.viewModel.signatureImage {
                    ImageResizableView(
                        uiImage: signatureImage,
                        imageRect: self.$viewModel.signatureRect,
                        borderColor: ColorPalette.thirdText,
                        borderWidth: 2,
                        handleColor: ColorPalette.buttonGradientStart,
                        handleSize: 10,
                        handleTapSize: 50
                    )
                }
            }
            .padding([.leading, .trailing], 16)
            .padding([.top], 16)
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Tap where you wish to sign")
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                if self.viewModel.isPositioningSignature {
                    self.showCancelWarningDialog = true
                } else {
                    self.dismiss()
                }
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        self.viewModel.onConfirmButtonPressed()
                        self.dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16).bold())
                            .foregroundColor(ColorPalette.buttonGradientStart)
                    }
                }
            }
            .sheet(isPresented: self.$viewModel.isCreatingSignature) {
                PdfSignatureCanvasView(viewModel: Container.shared.pdfSignatureCanvasViewModel({
                    self.viewModel.onSignatureCreated(signatureImage: $0)
                }))
                .background(ColorPalette.primaryText)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .presentationDetents([.height(400)])
            }
            .alert("Are you sure?",
                   isPresented: self.$showCancelWarningDialog,
                   actions: {
                Button("No", role: .cancel, action: {})
                Button("Yes", role: .destructive, action: {
                    self.dismiss()
                })
            }, message: { Text("If you quit, you will lose the signature you've just added.") })
        }
        .onAppear(perform: self.viewModel.onAppear)
    }
}

struct PdfSignatureView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdfEditable = K.Test.DebugPdfEditable {
            let inputParameter = PdfSignatureViewModel.InputParameter(pdfEditable: pdfEditable,
                                                                      currentPageIndex: 0,
                                                                      onConfirm: { _ in })
            AnyView(PdfSignatureView(viewModel: Container.shared.pdfSignatureViewModel(inputParameter)))
        } else {
            AnyView(Spacer())
        }
    }
}
