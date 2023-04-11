//
//  PdfViewerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import Factory
import PDFKit

struct PDFKitView: UIViewRepresentable {
    typealias UIViewType = PDFView

    let pdfDocument: PDFDocument?
    let singlePage: Bool
    let pageMargins: UIEdgeInsets?

    init(pdfDocument: PDFDocument?,
         singlePage: Bool = false,
         pageMargins: UIEdgeInsets? = nil) {
        self.pdfDocument = pdfDocument
        self.singlePage = singlePage
        self.pageMargins = pageMargins
    }

    func makeUIView(context: Context) -> UIViewType {
        let pdfView = PDFView()
        pdfView.document = self.pdfDocument
        pdfView.autoScales = true
        if self.singlePage {
            pdfView.displayMode = .singlePage
        }
        if let pageMargins = self.pageMargins {
            pdfView.pageBreakMargins = pageMargins
        }
        return pdfView
    }

    func updateUIView(_ pdfView: UIViewType, context: Context) {
        pdfView.document = self.pdfDocument
    }
}

struct PdfViewerView: View {
    
    @StateObject var pdfViewerViewModel: PdfViewerViewModel
    
    var body: some View {
        PDFKitView(
            pdfDocument: self.pdfViewerViewModel.pdf.pdfDocument,
            pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        )
        .padding([.leading, .trailing], 16)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { self.pdfViewerViewModel.share() }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
        }
        .fullScreenCover(isPresented: self.$pdfViewerViewModel.monetizationShow) {
            SubscriptionView(onComplete: { self.pdfViewerViewModel.monetizationShow = false })
        }
        .sheet(item: self.$pdfViewerViewModel.pdfToBeShared) { pdf in
            ActivityViewController(activityItems: [pdf.data!],
                                   thumbnail: pdf.thumbnail)
        }
    }
}

struct PdfViewerView_Previews: PreviewProvider {
    
    static var previews: some View {
        if let pdf = K.Test.DebugPdf {
            AnyView(PdfViewerView(pdfViewerViewModel: Container.shared.pdfViewerViewModel(pdf)))
        } else {
            AnyView(Spacer())
        }
    }
}
