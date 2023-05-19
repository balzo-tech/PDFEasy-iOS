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
                    PdfKitViewBinder(
                        pdfView: self.$viewModel.pdfView,
                        pdfDocument: self.viewModel.pdfEditable.pdfDocument,
                        singlePage: false,
                        pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0),
                        currentPage: nil,
                        backgroundColor: UIColor(ColorPalette.primaryBG),
                        usePaginator: true
                    )
                    .onTapGesture { self.viewModel.tapOnPdfView() }
                    .allowsHitTesting(self.viewModel.pageScrollingAllowed)
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
            .sheet(isPresented: self.$viewModel.isCreatingSignature) {
                PdfSignatureCanvasView(viewModel: Container.shared.pdfSignatureCanvasViewModel({
                    self.viewModel.onSignatureCreated(signatureImage: $0)
                }))
                .background(ColorPalette.primaryText)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .presentationDetents([.height(400)])
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

import PDFKit

struct PdfKitViewBinder: UIViewRepresentable {
    typealias UIViewType = PDFView

    @Binding var pdfView: PDFView
    let pdfDocument: PDFDocument?
    let singlePage: Bool
    let pageMargins: UIEdgeInsets?
    let currentPage: Int?
    let backgroundColor: UIColor?
    let usePaginator: Bool

    init(
        pdfView: Binding<PDFView>,
        pdfDocument: PDFDocument?,
        singlePage: Bool = false,
        pageMargins: UIEdgeInsets? = nil,
        currentPage: Int? = nil,
        backgroundColor: UIColor? = nil,
        usePaginator: Bool = false
    ) {
        self._pdfView = pdfView
        self.pdfDocument = pdfDocument
        self.singlePage = singlePage
        self.pageMargins = pageMargins
        self.currentPage = currentPage
        self.backgroundColor = backgroundColor
        self.usePaginator = usePaginator
    }

    func makeUIView(context: Context) -> UIViewType {
        self.updatePdfView(self.pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: UIViewType, context: Context) {
        self.updatePdfView(pdfView)
    }
    
    private func updatePdfView(_ pdfView: UIViewType) {
        pdfView.document = self.pdfDocument
        pdfView.autoScales = true
        self.updateBackground(pdfView: pdfView)
        self.updateSinglePage(pdfView: pdfView)
        self.updatePageMargins(pdfView: pdfView)
        self.updateCurrentPage(pdfView: pdfView)
        self.updateUsePaginator(pdfView: pdfView)
    }
    
    private func updateBackground(pdfView: UIViewType) {
        if let backgroundColor = self.backgroundColor {
            pdfView.backgroundColor = backgroundColor
        }
    }
    
    private func updateSinglePage(pdfView: UIViewType) {
        if self.singlePage {
            pdfView.displayMode = .singlePage
        }
    }
    
    private func updatePageMargins(pdfView: UIViewType) {
        if let pageMargins = self.pageMargins {
            pdfView.pageBreakMargins = pageMargins
        }
    }
    
    private func updateCurrentPage(pdfView: UIViewType) {
        if let currentPage = self.currentPage,
           currentPage >= 0,
           currentPage < self.pdfDocument?.pageCount ?? 0,
           let page = self.pdfDocument?.page(at: currentPage) {
            pdfView.go(to: page)
        }
    }
    
    private func updateUsePaginator(pdfView: UIViewType) {
        pdfView.usePageViewController(self.usePaginator)
    }
}

struct PdfKitViewBinder_Previews: PreviewProvider {
    
    static let pdfView = PDFView()
    
    static var previews: some View {
        PdfKitViewBinder(
            pdfView: .constant(pdfView),
            pdfDocument: K.Test.DebugPdfDocument,
            singlePage: false,
            pageMargins: nil,
            currentPage: nil,
            backgroundColor: nil,
            usePaginator: true
        )
    }
}
