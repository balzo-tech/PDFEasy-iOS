//
//  PdfFillFormView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 26/05/23.
//

import SwiftUI
import Factory
import PDFKit

struct PdfFillFormView: View {
    
    @StateObject var viewModel: PdfFillFormViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { parentGeometryReader in
                TabView(selection: self.$viewModel.pageIndex) {
                    ForEach(Array(self.viewModel.pageImages.enumerated()), id:\.offset) { (pageIndex, page) in
                        GeometryReader { geometryReader in
                            ZStack {
                                Image(uiImage: page)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .ignoresSafeArea(.keyboard)
                                self.getAnnotationViews(forPageIndex: pageIndex)
                                    .ignoresSafeArea(.keyboard)
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
                .tabViewStyle(.page)
                .position(x: parentGeometryReader.size.width / 2, y: parentGeometryReader.size.height / 2)
                .frame(width: parentGeometryReader.size.width,
                       height: parentGeometryReader.size.width * (K.Misc.PdfPageSize.height / K.Misc.PdfPageSize.width))
            }
            .padding([.leading, .trailing], 16)
            .padding([.top], 16)
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Tap where you wish to add text")
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.viewModel.onCancelButtonPressed()
                self.dismiss()
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
        }
        .onAppear(perform: self.viewModel.onAppear)
    }
    
    @ViewBuilder func getAnnotationViews(forPageIndex pageIndex: Int) -> some View {
        ForEach(self.viewModel.getAnnotations(forPageIndex: pageIndex), id:\.self) { pageAnnotation in
            self.getView(forAnnotation: pageAnnotation)
        }
        if self.viewModel.editedPageIndex == pageIndex {
            TextResizableView(data: self.$viewModel.currentTextResizableViewData,
                              fontName: K.Misc.DefaultAnnotationTextFontName,
                              fontColor: .black,
                              color: .orange,
                              borderWidth: 4,
                              minSize: CGSize(width: 5, height: 5),
                              handleSize: 25,
                              handleTapSize: 50,
                              deleteCallback: self.viewModel.onDeleteAnnotationPressed)
        }
    }
    
    @ViewBuilder func getView(forAnnotation annotation: PDFAnnotation) -> some View {
        if let page = annotation.page {
            GeometryReader { geometryReader in
                let annotationBounds = PdfFillFormViewModel.convertRect(annotation.verticalCenteredTextBounds,
                                                                        viewSize: geometryReader.size,
                                                                        fromPage: page)
                let position = CGPoint(x: annotationBounds.origin.x + annotationBounds.size.width / 2,
                                       y: annotationBounds.origin.y + annotationBounds.size.height / 2)
                Text(annotation.contents ?? "")
                    .font(Font(UIFont.font(named: K.Misc.DefaultAnnotationTextFontName,
                                           fitting: annotation.contents ?? "",
                                           into: annotationBounds.size,
                                           with: [:],
                                           options: [])))
                    .foregroundColor(Color(annotation.fontColor ?? .black))
                    .frame(width: annotationBounds.width, height: annotationBounds.height)
                    .position(position)
            }
        }
    }
}

struct PdfFillFormView_Previews: PreviewProvider {
    static var previews: some View {
        if let pdfEditable = K.Test.DebugPdfEditable {
            let inputParameter = PdfFillFormViewModel.InputParameter(pdfEditable: pdfEditable,
                                                                     currentPageIndex: 0,
                                                                     onConfirm: { _ in })
            AnyView(PdfFillFormView(viewModel: Container.shared.pdfFillFormViewModel(inputParameter)))
        } else {
            AnyView(Spacer())
        }
    }
}
