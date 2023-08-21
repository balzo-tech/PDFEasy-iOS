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
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(self.viewModel.pdf.filename)
                .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                    self.dismiss()
                })
                self.pageCounter(currentPageIndex: self.viewModel.pageIndex,
                                 totalPages: self.viewModel.pdf.pageCount)
            }
            .padding(16)
            .background(ColorPalette.primaryBG)
        }
        .background(ColorPalette.primaryBG)
        .onAppear(perform: self.viewModel.onAppear)
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
