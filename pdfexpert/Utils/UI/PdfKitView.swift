//
//  PdfKitView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import PDFKit

struct PdfKitView: UIViewRepresentable {
    typealias UIViewType = PDFView

    let pdfDocument: PDFDocument?
    let singlePage: Bool
    let pageMargins: UIEdgeInsets?
    let currentPage: Int?
    let backgroundColor: UIColor?

    init(
        pdfDocument: PDFDocument?,
        singlePage: Bool = false,
        pageMargins: UIEdgeInsets? = nil,
        currentPage: Int? = nil,
        backgroundColor: UIColor? = nil
    ) {
        self.pdfDocument = pdfDocument
        self.singlePage = singlePage
        self.pageMargins = pageMargins
        self.currentPage = currentPage
        self.backgroundColor = backgroundColor
    }

    func makeUIView(context: Context) -> UIViewType {
        let pdfView = PDFView()
        pdfView.document = self.pdfDocument
        pdfView.autoScales = true
        self.updateBackground(pdfView: pdfView)
        self.updateSinglePage(pdfView: pdfView)
        self.updatePageMargins(pdfView: pdfView)
        self.updateCurrentPage(pdfView: pdfView)
        return pdfView
    }

    func updateUIView(_ pdfView: UIViewType, context: Context) {
        pdfView.document = self.pdfDocument
        self.updateBackground(pdfView: pdfView)
        self.updateSinglePage(pdfView: pdfView)
        self.updatePageMargins(pdfView: pdfView)
        self.updateCurrentPage(pdfView: pdfView)
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
}

struct PdfKitView_Previews: PreviewProvider {
    static var previews: some View {
        PdfKitView(pdfDocument: nil)
    }
}
