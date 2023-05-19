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
    
    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { geometryReader in
                    PdfKitView(
                        pdfDocument: self.viewModel.pdfEditable.pdfDocument,
                        singlePage: false,
                        pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0),
                        currentPage: nil,
                        backgroundColor: UIColor(ColorPalette.primaryBG),
                        usePaginator: true,
                        onTapPage: { page in
                            if let page = page {
                                self.viewModel.tapOnPdfView(page: page, pdfViewSize: geometryReader.size)
                            }
                        },
                        viewRect: self.$viewModel.signatureRect,
                        viewToPageRectConversionCallback: { self.viewModel.signaturePageRect = $0 }
                    )
                }
                if self.viewModel.editingSignature, let image = self.viewModel.image {
                    ImageResizableView(
                        uiImage: image,
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
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: { self.dismiss() })
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
        }
    }
}

struct PdfSignatureView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdfEditable = K.Test.DebugPdfEditable {
            let inputParameter = PdfSignatureViewModel.InputParameter(pdfEditable: pdfEditable,
                                                                      onConfirm: { _ in })
            AnyView(PdfSignatureView(viewModel: Container.shared.pdfSignatureViewModel(inputParameter)))
        } else {
            AnyView(Spacer())
        }
    }
}
