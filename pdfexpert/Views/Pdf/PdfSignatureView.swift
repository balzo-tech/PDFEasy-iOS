//
//  PdfSignatureView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 10/05/23.
//

import SwiftUI
import Factory
import PDFKit

struct PdfSignatureView: View {
    
    @StateObject var viewModel: PdfSignatureViewModel
    @Environment(\.dismiss) var dismiss
    @State var showCancelWarningDialog: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Spacer()
                    self.pdfView
                    Spacer()
                }
                self.pageCounter(currentPageIndex: self.viewModel.pageIndex,
                                 totalPages: self.viewModel.pageImages.count)
                Spacer().frame(height: 50)
                self.getDefaultButton(text: "Finish", onButtonPressed: {
                    self.viewModel.onConfirmButtonPressed()
                    self.dismiss()
                })
                Spacer().frame(height: 60)
            }
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Tap where you wish to sign")
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                if self.viewModel.unsavedChangesExist {
                    self.showCancelWarningDialog = true
                } else {
                    self.dismiss()
                }
            })
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
    
    var pdfView: some View {
        VStack(spacing: 0) {
            Spacer()
            GeometryReader { parentGeometryReader in
                TabView(selection: self.$viewModel.pageIndex) {
                    ForEach(Array(self.viewModel.pageImages.enumerated()), id:\.offset) { (pageIndex, page) in
                        GeometryReader { geometryReader in
                            HStack {
                                Spacer()
                                ZStack {
                                    Image(uiImage: page)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .ignoresSafeArea(.keyboard)
                                    self.getAnnotationViews(forPageIndex: pageIndex)
                                        .ignoresSafeArea(.keyboard)
                                }
                                Spacer()
                            }
                            .onTapGesture {
                                self.viewModel.tapOnPdfView(positionInView: $0,
                                                            pageIndex: pageIndex,
                                                            pageViewSize: geometryReader.size)
                            }
                            .position(x: geometryReader.size.width / 2, y: geometryReader.size.height / 2)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .position(x: parentGeometryReader.size.width / 2, y: parentGeometryReader.size.height / 2)
                .frame(width: parentGeometryReader.size.width,
                       height: parentGeometryReader.size.height)
            }
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Tap where you wish to add text")
            Spacer()
        }
    }
    
    @ViewBuilder func getAnnotationViews(forPageIndex pageIndex: Int) -> some View {
        ForEach(self.viewModel.getAnnotations(forPageIndex: pageIndex), id:\.self) { pageAnnotation in
            self.getView(forAnnotation: pageAnnotation)
        }
        if self.viewModel.editedPageIndex == pageIndex, let signatureImage = self.viewModel.signatureImage {
            ImageResizableView(
                uiImage: signatureImage,
                imageRect: self.$viewModel.signatureRect,
                borderColor: ColorPalette.thirdText,
                borderWidth: 2,
                handleColor: ColorPalette.buttonGradientStart,
                handleSize: 10,
                handleTapSize: 50,
                deleteCallback: { self.viewModel.onDeleteAnnotationPressed() }
            )
        }
    }
    
    @ViewBuilder func getView(forAnnotation annotation: PDFAnnotation) -> some View {
        if let page = annotation.page {
            GeometryReader { geometryReader in
                let annotationBounds = self.viewModel.convertRect(annotation.bounds,
                                                                        viewSize: geometryReader.size,
                                                                        fromPage: page)
                let position = CGPoint(x: annotationBounds.origin.x + annotationBounds.size.width / 2,
                                       y: annotationBounds.origin.y + annotationBounds.size.height / 2)
                Image(uiImage: annotation.image)
                    .resizable()
                    .frame(width: annotationBounds.width, height: annotationBounds.height)
                    .position(position)
            }
        }
    }
}

struct PdfSignatureView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdf = K.Test.DebugPdf {
            let inputParameter = PdfSignatureViewModel.InputParameter(pdf: pdf,
                                                                      currentPageIndex: 0,
                                                                      onConfirm: { _ in })
            AnyView(PdfSignatureView(viewModel: Container.shared.pdfSignatureViewModel(inputParameter)))
        } else {
            AnyView(Spacer())
        }
    }
}
