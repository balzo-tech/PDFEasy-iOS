//
//  PdfViewerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import Factory

struct PdfViewerView: View {
    
    @StateObject var viewModel: PdfViewerViewModel
    
    var body: some View {
        PdfKitView(
            pdfDocument: self.viewModel.pdf.pdfDocument,
            singlePage: false,
            pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0),
            currentPage: nil,
            backgroundColor: UIColor(ColorPalette.primaryBG)
        )
        .padding([.leading, .trailing], 16)
        .background(ColorPalette.primaryBG)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { self.viewModel.share() }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
        }
        .fullScreenCover(isPresented: self.$viewModel.monetizationShow) {
            self.getSubscriptionView(onComplete: {
                self.viewModel.monetizationShow = false
            })
        }
        .sheet(item: self.$viewModel.pdfToBeShared) { pdf in
            ActivityViewController(activityItems: [pdf.data!],
                                   thumbnail: pdf.thumbnail)
        }
    }
}

struct PdfViewerView_Previews: PreviewProvider {
    
    static var previews: some View {
        if let pdf = K.Test.DebugPdf {
            AnyView(PdfViewerView(viewModel: Container.shared.pdfViewerViewModel(pdf)))
        } else {
            AnyView(Spacer())
        }
    }
}
