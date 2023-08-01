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

typealias PdfSignatureCallback = ((Pdf) -> ())

class PdfSignatureViewModel: ObservableObject {
    
    struct InputParameter {
        let pdf: Pdf
        let currentPageIndex: Int
        let onConfirm: PdfSignatureCallback
    }
    
    @Published var pdfCurrentPageIndex: Int = 0 {
        didSet {
            guard let page = self.pdf.pdfDocument.page(at: self.pdfCurrentPageIndex) else {
                return
            }
            self.pdfView.go(to: page)
        }
    }
    @Published var pageImages: [UIImage]
    @Published var pdf: Pdf
    @Published var isCreatingSignature: Bool = false { didSet { self.updatePdfViewInteraction() } }
    @Published var signatureRect: CGRect = .zero
    @Published var signatureImage: UIImage? = nil { didSet { self.updatePdfViewInteraction() } }
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    var pageScrollingAllowed: Bool { !self.isPositioningSignature && !self.isCreatingSignature }
    
    var isPositioningSignature: Bool { self.signatureImage != nil }
    
    private var onConfirm: PdfSignatureCallback
    
    var pdfView: PDFView = PDFView()
    
    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        
        self.onConfirm = inputParameter.onConfirm
        
        var pageImages: [UIImage] = []
        for pageIndex in 0..<inputParameter.pdf.pdfDocument.pageCount {
            if let page = inputParameter.pdf.pdfDocument.page(at: pageIndex) {
                pageImages.append(page.thumbnail(of: page.bounds(for: .mediaBox).size, for: .mediaBox))
            }
        }
        self.pageImages = pageImages
        
        self.pdfView.document = inputParameter.pdf.pdfDocument
        
        if let page = self.pdfView.document?.page(at: inputParameter.currentPageIndex) {
            self.pdfView.go(to: page)
        }
        self.pdfCurrentPageIndex = inputParameter.currentPageIndex
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.signature))
    }
    
    func onConfirmButtonPressed() {
        // This distinction between view page and standard page is a workaround to prevent user interaction with annotations. See init.
        if let currentPage = self.pdf.pdfDocument.page(at: self.pdfCurrentPageIndex),
           let currentViewPage = self.pdfView.currentPage,
           let signatureImage = self.signatureImage {
            let signaturePageRect = self.pdfView.convert(self.signatureRect, to: currentViewPage)
            let signatureAnnotation = ImageStampAnnotation(with: signatureImage, forBounds: signaturePageRect, withProperties: nil)
            currentPage.addAnnotation(signatureAnnotation)
            
            self.analyticsManager.track(event: .signatureAdded)
            
            self.onConfirm(self.pdf)
        }
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
