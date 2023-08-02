//
//  PdfUnlockViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 02/08/23.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfUnlockViewModel: ParameterFactory<PdfUnlockViewModel.Params, PdfUnlockViewModel> {
        self { PdfUnlockViewModel(params: $0) }
    }
}

class PdfUnlockViewModel: ObservableObject {
    
    struct Params {
        let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    }
    
    @Published var showPasswordInputView: Bool = false
    @Published var passwordText: String = ""
    
    var pdf: Pdf? = nil
    
    private let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    
    init(params: Params) {
        self.asyncPdf = params.asyncPdf
    }
    
    func unlock(pdf: Pdf) {
        // Must skip a frame to make the view correctly dismiss and show again the password input alert
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            guard pdf.pdfDocument.isLocked else {
                self.asyncPdf.wrappedValue = AsyncOperation(status: .data(pdf))
                return
            }
            self.pdf = pdf
            self.showPasswordInputView = true
        }
    }
    
    func decryptPdf() {
        guard let pdf = self.pdf else {
            assertionFailure("Missing expected pdf")
            self.asyncPdf.wrappedValue = AsyncOperation(status: .empty)
            return
        }
        self.asyncPdf.wrappedValue = PDFUtility.decryptFile(pdf: pdf, password: self.passwordText)
        self.pdf = nil
    }
}
