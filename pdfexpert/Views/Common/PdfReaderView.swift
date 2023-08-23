//
//  PdfReaderView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import SwiftUI
import Factory

struct PdfReaderView: View {
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: PdfReaderViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TabView(selection: self.$viewModel.pageIndex) {
                    ForEach(Array(self.viewModel.pages.enumerated()), id:\.offset) { _, page in
                        if let page = page {
                            ScrollView {
                                Text(page)
                            }
                        } else {
                            Text("No text available on this page")
                                .font(FontPalette.fontMedium(withSize: 16))
                                .foregroundColor(ColorPalette.primaryText)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(ColorPalette.primaryBG)
                self.pageCounter(currentPageIndex: self.viewModel.pageIndex,
                                 totalPages: self.viewModel.pdfPageCount)
            }
            .padding(16)
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(self.viewModel.pdfFileName)
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.dismiss()
            })
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { self.viewModel.presentPageImages() }) {
                        Image(systemName: "photo.stack")
                            .foregroundColor(ColorPalette.primaryText)
                    }
                    Button(action: { self.viewModel.presentPageSelection() }) {
                        Image("page_selection")
                            .foregroundColor(ColorPalette.primaryText)
                    }
                }
            }
            .fullScreenCover(isPresented: self.$viewModel.showPageSelection) {
                PdfPageSelectionView(pageIndex: self.$viewModel.pageIndex,
                                     title: self.viewModel.pdfFileName,
                                     pageThumbnails: self.viewModel.pageThumbnails.data ?? [])
            }
            .fullScreenCover(isPresented: self.$viewModel.showPageImages) {
                PdfImageViewerView(pageIndex: self.viewModel.pageIndex,
                                   images: self.viewModel.pageImages.data ?? [])
            }
        }
        .background(ColorPalette.primaryBG)
        .onAppear(perform: self.viewModel.onAppear)
        .asyncView(asyncItem: self.$viewModel.pageThumbnails)
        .asyncView(asyncItem: self.$viewModel.pageImages)
    }
}

extension View {
    func showPdfReaderView(item: Binding<Pdf?>) -> some View {
        self.fullScreenCover(item: item) { pdf in
            let params = PdfReaderViewModel.Params(pdf: pdf)
            let viewModel = Container.shared.pdfReaderViewModel(params)
            PdfReaderView(viewModel: viewModel)
        }
    }
}

struct PdfReaderView_Previews: PreviewProvider {
    
    static var previews: some View {
        Color.white
            .showPdfReaderView(item: .constant(K.Test.DebugPdf))
    }
}
