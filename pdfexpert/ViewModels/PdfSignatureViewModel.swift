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

extension Container {
    var pdfSignatureViewModel: ParameterFactory<PdfSignatureViewModel.InputParameter, PdfSignatureViewModel> {
        self { PdfSignatureViewModel(inputParameter: $0) }.shared
    }
}

typealias PdfSignatureCallback = ((PdfEditable) -> ())

class PdfSignatureViewModel: ObservableObject {
    
    struct InputParameter {
        let pdfEditable: PdfEditable
        let onConfirm: PdfSignatureCallback
    }
    
    @Published var pdfEditable: PdfEditable
    @Published var editingSignature: Bool = false
    @Published var signatureRect: CGRect = .zero
    @Published var image: UIImage? = UIImage(named: "gallery")
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    var signaturePageRect: CGRect = .zero
    
    private var onConfirm: PdfSignatureCallback
    private var currentPage: PDFPage?
    
    init(inputParameter: InputParameter) {
        self.pdfEditable = inputParameter.pdfEditable
        self.onConfirm = inputParameter.onConfirm
    }
    
    func onConfirmButtonPressed() {
        
        if let currentPage = self.currentPage, let image = self.image {
            let signatureAnnotation = ImageStampAnnotation(with: image, forBounds: self.signaturePageRect, withProperties: nil)
            currentPage.addAnnotation(signatureAnnotation)
        }
        
        self.onConfirm(self.pdfEditable)
    }
    
    func tapOnPdfView(page: PDFPage, pdfViewSize: CGSize) {
        if let image = self.image {
            let imageSize: CGSize = image.size
            self.signatureRect = CGRect(origin: CGPoint(x: pdfViewSize.width * 0.5 - imageSize.width / 2,
                                                        y: pdfViewSize.height * 0.5 - imageSize.height / 2) ,
                                        size: imageSize)
            self.currentPage = page
            self.editingSignature = true
        }
    }
}
