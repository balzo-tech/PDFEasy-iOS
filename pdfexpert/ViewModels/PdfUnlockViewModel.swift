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
        let asyncUnlockedPdfMultipleOutput: Binding<AsyncOperation<[Pdf], PdfError>>?
        let asyncUnlockedPdfSingleOutput: Binding<AsyncOperation<Pdf, PdfError>>?
        
        init(asyncUnlockedPdfMultipleOutput: Binding<AsyncOperation<[Pdf], PdfError>>) {
            self.asyncUnlockedPdfMultipleOutput = asyncUnlockedPdfMultipleOutput
            self.asyncUnlockedPdfSingleOutput = nil
        }
        
        init(asyncUnlockedPdfSingleOutput: Binding<AsyncOperation<Pdf, PdfError>>) {
            self.asyncUnlockedPdfMultipleOutput = nil
            self.asyncUnlockedPdfSingleOutput = asyncUnlockedPdfSingleOutput
        }
    }
    
    @Published var showPasswordInputView: Bool = false
    @Published var passwordText: String = ""
    @Published var asyncUnlockedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            switch self.asyncUnlockedPdf.status {
            case .empty:
                // Just in case this reset is caused by an error alert dismiss, go the next pdf
                self.unlockNextPdf()
            case .loading:
                break
            case .error:
                // The error will be shown in the view
                break
            case .data(let unlockedPdf):
                self.onUnlockCompleted(forPdf: unlockedPdf)
            }
        }
    }
    
    var unlockingPdf: Pdf? = nil
    
    private let asyncUnlockedPdfMultipleOutput: Binding<AsyncOperation<[Pdf], PdfError>>?
    private let asyncUnlockedPdfSingleOutput: Binding<AsyncOperation<Pdf, PdfError>>?
    
    private var toBeUnlockedPdfs: [Pdf] = []
    private var unlockedPdfs: [Pdf] = []
    
    init(params: Params) {
        self.asyncUnlockedPdfMultipleOutput = params.asyncUnlockedPdfMultipleOutput
        self.asyncUnlockedPdfSingleOutput = params.asyncUnlockedPdfSingleOutput
    }
    
    func unlockPdfs(pdfs: [Pdf]) {
        guard pdfs.count > 0 else {
            self.asyncUnlockedPdfMultipleOutput?.wrappedValue = .init(status: .empty)
            self.asyncUnlockedPdfSingleOutput?.wrappedValue = .init(status: .empty)
            return
        }
        self.toBeUnlockedPdfs = pdfs
        self.unlockNextPdf()
    }
    
    func unlockPdf(pdf: Pdf) {
        // Must skip a frame to make the view correctly dismiss and show again the password input alert
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if pdf.pdfDocument.isLocked {
                self.unlockingPdf = pdf
                self.showPasswordInputView = true
            } else {
                self.onUnlockCompleted(forPdf: pdf)
            }
        }
    }
    
    @MainActor
    func decryptPdf() {
        guard let pdf = self.unlockingPdf else {
            assertionFailure("Missing expected pdf")
            self.asyncUnlockedPdf = AsyncOperation(status: .empty)
            return
        }
        self.asyncUnlockedPdf = .init(status: .loading(Progress(totalUnitCount: 1)))
        Task {
            let task = Task<AsyncOperation<Pdf, PdfError>, Never> {
                return PDFUtility.decryptFile(pdf: pdf, password: self.passwordText)
            }
            self.asyncUnlockedPdf = await task.value
            self.passwordText = ""
            self.unlockingPdf = nil
        }
    }
    
    private func unlockNextPdf() {
        guard let pdf = self.toBeUnlockedPdfs.popLast() else {
            self.asyncUnlockedPdfMultipleOutput?.wrappedValue = AsyncOperation(status: .data(self.unlockedPdfs))
            if let unlockedPdf = self.unlockedPdfs.first {
                self.asyncUnlockedPdfSingleOutput?.wrappedValue = AsyncOperation(status: .data(unlockedPdf))
            } else {
                self.asyncUnlockedPdfSingleOutput?.wrappedValue = AsyncOperation(status: .empty)
            }
            self.unlockedPdfs = []
            return
        }
        
        self.unlockPdf(pdf: pdf)
    }
    
    private func onUnlockCompleted(forPdf pdf: Pdf) {
        self.unlockedPdfs.append(pdf)
        self.unlockNextPdf()
    }
}
