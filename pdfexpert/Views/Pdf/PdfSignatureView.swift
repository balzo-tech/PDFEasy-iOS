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
                // This PDFView is behind everything so that it can be easily laid out
                // and used for rect conversion.
                // TODO: Improve this removing the need of a PDFView (especially in the view hierarchy)
                PdfKitViewBinder(
                    pdfView: self.$viewModel.pdfView,
                    singlePage: false,
                    pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0),
                    backgroundColor: UIColor(ColorPalette.primaryBG),
                    usePaginator: true
                )
                ColorPalette.primaryBG
                TabView(selection: self.$viewModel.pdfCurrentPageIndex) {
                    ForEach(Array(self.viewModel.pageImages.enumerated()), id:\.offset) { (pageIndex, page) in
                        GeometryReader { geometryReader in
                            ZStack {
                                Image(uiImage: page)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .ignoresSafeArea(.keyboard)
                            }
                            .position(x: geometryReader.size.width / 2, y: geometryReader.size.height / 2)
                        }
                    }
                }
                .allowsHitTesting(self.viewModel.pageScrollingAllowed)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onTapGesture { self.viewModel.tapOnPdfView() }
                .padding([.leading, .trailing], 16)
                .padding([.top], 16)
                .background(ColorPalette.primaryBG)
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
            .formSheet(isPresented: self.$viewModel.isCreatingSignature,
                       size: CGSize(width: 400, height: 400)) {
                PdfSignatureCanvasView(viewModel: Container.shared.pdfSignatureCanvasViewModel({
                    self.viewModel.onSignatureCreated(signatureImage: $0)
                }))
                .background(ColorPalette.primaryText)
                .cornerRadius(20, corners: [.topLeft, .topRight])
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
