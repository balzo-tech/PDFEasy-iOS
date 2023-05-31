//
//  PdfKitViewBinder.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/05/23.
//

import SwiftUI
import PDFKit

struct PdfKitViewBinder: UIViewRepresentable {
    typealias UIViewType = PDFView

    @Binding var pdfView: PDFView
    let singlePage: Bool
    let pageMargins: UIEdgeInsets?
    let backgroundColor: UIColor?
    let usePaginator: Bool

    init(
        pdfView: Binding<PDFView>,
        singlePage: Bool = false,
        pageMargins: UIEdgeInsets? = nil,
        backgroundColor: UIColor? = nil,
        usePaginator: Bool = false
    ) {
        self._pdfView = pdfView
        self.singlePage = singlePage
        self.pageMargins = pageMargins
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
        pdfView.autoScales = true
        self.updateBackground(pdfView: pdfView)
        self.updateSinglePage(pdfView: pdfView)
        self.updatePageMargins(pdfView: pdfView)
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
    
    private func updateUsePaginator(pdfView: UIViewType) {
        pdfView.usePageViewController(self.usePaginator)
    }
}

struct PdfKitViewBinder_Previews: PreviewProvider {
    
    static let pdfView = {
        let pdfView = PDFView()
        pdfView.document = K.Test.DebugPdfDocument
        return pdfView
    }()
    
    static var previews: some View {
        PdfKitViewBinder(
            pdfView: .constant(pdfView),
//            pdfViewOverlayProvider: .constant(nil),
            singlePage: false,
            pageMargins: nil,
            backgroundColor: nil,
            usePaginator: true
        )
    }
}
