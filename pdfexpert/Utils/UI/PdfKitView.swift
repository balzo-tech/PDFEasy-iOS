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
    typealias OnTapPageCallback = ((PDFPage?) -> ())
    typealias ViewToPageRectConversionCallback = ((CGRect) -> ())

    let pdfDocument: PDFDocument?
    let singlePage: Bool
    let pageMargins: UIEdgeInsets?
    let currentPage: Int?
    let backgroundColor: UIColor?
    let usePaginator: Bool
    let onTapPage: OnTapPageCallback?
    var viewRect: Binding<CGRect>?
    var viewToPageRectConversionCallback: ViewToPageRectConversionCallback?

    init(
        pdfDocument: PDFDocument?,
        singlePage: Bool = false,
        pageMargins: UIEdgeInsets? = nil,
        currentPage: Int? = nil,
        backgroundColor: UIColor? = nil,
        usePaginator: Bool = false,
        onTapPage: OnTapPageCallback? = nil,
        viewRect: Binding<CGRect>? = nil,
        viewToPageRectConversionCallback: ViewToPageRectConversionCallback? = nil
    ) {
        self.pdfDocument = pdfDocument
        self.singlePage = singlePage
        self.pageMargins = pageMargins
        self.currentPage = currentPage
        self.backgroundColor = backgroundColor
        self.usePaginator = usePaginator
        self.onTapPage = onTapPage
        self.viewRect = viewRect
        self.viewToPageRectConversionCallback = viewToPageRectConversionCallback
    }

    func makeUIView(context: Context) -> UIViewType {
        let pdfView = PDFView()
        self.updatePdfView(pdfView)
        if nil != self.onTapPage {
            let tapGesture = UITapGestureRecognizer(target: context.coordinator,
                                                    action: #selector(context.coordinator.onTap))
            tapGesture.delegate = context.coordinator
            pdfView.addGestureRecognizer(tapGesture)
        }
        return pdfView
    }
    
    func makeCoordinator() -> PdfKitViewCoordinator {
        PdfKitViewCoordinator(onTapPage: { [self] tap in
            guard let onTapPage = self.onTapPage,
                  let pdfView = tap.view as? PDFView else { return }
            let position = tap.location(in: tap.view)
            onTapPage(pdfView.page(for: position, nearest: false))
        })
    }

    func updateUIView(_ pdfView: UIViewType, context: Context) {
        self.updatePdfView(pdfView)
        if let page = pdfView.currentPage, let viewRect = self.viewRect?.wrappedValue {
            self.viewToPageRectConversionCallback?(pdfView.convert(viewRect, to: page))
        }
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

class PdfKitViewCoordinator: NSObject, UIGestureRecognizerDelegate {
    
    typealias OnTapPageCallback = ((UITapGestureRecognizer) -> ())
    
    let onTapPage: OnTapPageCallback?

    init(onTapPage: OnTapPageCallback? = nil) {
        self.onTapPage = onTapPage
    }
    
    @objc func onTap(sender: UITapGestureRecognizer) {
        self.onTapPage?(sender)
    }
}

struct PdfKitView_Previews: PreviewProvider {
    static var previews: some View {
        PdfKitView(
            pdfDocument: K.Test.DebugPdfDocument,
            singlePage: false,
            pageMargins: nil,
            currentPage: nil,
            backgroundColor: nil,
            usePaginator: true,
            onTapPage: { page in print("Test Tap. Page hash: \(page.hashValue)") }
        )
    }
}
