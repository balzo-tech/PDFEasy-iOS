//
//  PdfSignatureViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 10/05/23.
//

import Foundation
import Factory
import PDFKit
import UIKit
import PencilKit

extension Container {
    var pdfSignatureViewModel: ParameterFactory<PdfSignatureViewModel.InputParameter, PdfSignatureViewModel> {
        self { PdfSignatureViewModel(inputParameter: $0) }
    }
}

typealias PdfSignatureCallback = ((PdfEditable) -> ())

class PdfSignatureViewModel: ObservableObject {
    
    struct InputParameter {
        let pdfEditable: PdfEditable
        let currentPageIndex: Int
        let onConfirm: PdfSignatureCallback
    }
    
    @Published var pdfView: PDFView = PDFView()
    @Published var pdfEditable: PdfEditable
    @Published var isCreatingSignature: Bool = false { didSet { self.updatePdfViewInteraction() } }
    @Published var signatureRect: CGRect = .zero
    @Published var signatureImage: UIImage? = nil { didSet { self.updatePdfViewInteraction() } }
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    var pageScrollingAllowed: Bool { !self.isPositioningSignature && !self.isCreatingSignature }
    
    var isPositioningSignature: Bool { self.signatureImage != nil }
    
    private var onConfirm: PdfSignatureCallback
    private var currentPageIndex: Int? {
        for pageIndex in 0..<self.pdfEditable.pdfDocument.pageCount {
            if self.pdfView.document?.page(at: pageIndex) == self.pdfView.currentPage {
                return pageIndex
            }
        }
        return nil
    }
    
    init(inputParameter: InputParameter) {
        self.pdfEditable = inputParameter.pdfEditable
        
        self.onConfirm = inputParameter.onConfirm
        // The document is copied and each page rasterized to prevent user interaction with annotations.
        self.pdfView.document = PDFUtility.applyPostProcess(toPdfDocument: inputParameter.pdfEditable.pdfDocument, horizontalMargin: 0, quality: 1.0)
        if let page = self.pdfView.document?.page(at: inputParameter.currentPageIndex) {
            self.pdfView.go(to: page)
        }
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.signature))
    }
    
    func onConfirmButtonPressed() {
        // This distinction between view page and standard page is a workaround to prevent user interaction with annotations. See init.
        if let currentPageIndex = self.currentPageIndex,
           let currentPage = self.pdfEditable.pdfDocument.page(at: currentPageIndex),
           let currentViewPage = self.pdfView.currentPage,
           let signatureImage = self.signatureImage {
            let signaturePageRect = self.pdfView.convert(signatureRect, to: currentViewPage)
            let signatureAnnotation = ImageStampAnnotation(with: signatureImage, forBounds: signaturePageRect, withProperties: nil)
            currentPage.addAnnotation(signatureAnnotation)
            
            self.analyticsManager.track(event: .signatureAdded)
        }
        
        self.onConfirm(self.pdfEditable)
    }
    
    func tapOnPdfView() {
        if !self.isPositioningSignature && !self.isCreatingSignature {
            self.isCreatingSignature = true
        }
    }
    
    func onSignatureCreated(signatureImage: UIImage) {
        self.analyticsManager.track(event: .signatureCreated)
        self.signatureImage = signatureImage
        self.signatureRect = CGRect(origin: CGPoint(x: self.pdfView.bounds.size.width * 0.5 - signatureImage.size.width / 2,
                                                    y: self.pdfView.bounds.size.height * 0.5 - signatureImage.size.height / 2) ,
                                    size: signatureImage.size)
        self.isCreatingSignature = false
    }
    
    private func updatePdfViewInteraction() {
        // this is an alternative to allowHitTest, since that one caused the view model to memory leak.
        self.pdfView.isUserInteractionEnabled = self.pageScrollingAllowed
    }
}
