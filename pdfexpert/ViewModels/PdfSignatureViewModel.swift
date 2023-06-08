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
        self { PdfSignatureViewModel(inputParameter: $0) }.shared
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
    @Published var isCreatingSignature: Bool = false
    @Published var signatureRect: CGRect = .zero
    @Published var signatureImage: UIImage? = nil
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    var pageScrollingAllowed: Bool { !self.isPositioningSignature && !self.isCreatingSignature }
    
    var isPositioningSignature: Bool { self.signatureImage != nil }
    
    private var onConfirm: PdfSignatureCallback
    
    init(inputParameter: InputParameter) {
        self.pdfEditable = inputParameter.pdfEditable
        
        self.onConfirm = inputParameter.onConfirm
        self.pdfView.document = PDFUtility.applyPostProcess(toPdfDocument: inputParameter.pdfEditable.pdfDocument, horizontalMargin: 0, quality: 1.0)
        if let page = self.pdfView.document?.page(at: inputParameter.currentPageIndex) {
            self.pdfView.go(to: page)
        }
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.signature))
    }
    
    func onConfirmButtonPressed() {
        
        if let currentPage = self.pdfView.currentPage, let signatureImage = self.signatureImage {
            let signaturePageRect = self.pdfView.convert(signatureRect, to: currentPage)
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
}
