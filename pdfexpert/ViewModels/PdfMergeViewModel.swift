//
//  PdfMergeViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 02/08/23.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfMergeViewModel: ParameterFactory<PdfMergeViewModel.Params, PdfMergeViewModel> {
        self { PdfMergeViewModel(params: $0) }
    }
}

class PdfMergeViewModel: ObservableObject {
    
    struct Params {
        let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    }
    
    @Published var showFilePicker: Bool = false
    @Published var showMergeManager: Bool = false
    @Published var asyncUnlockedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            switch self.asyncUnlockedPdf.status {
            case .empty:
                // Just in case this reset is caused by an error alert dismiss, go the next pdf
                self.processNextPdf()
            case .loading:
                break
            case .error:
                // The error will be shown in the view
                break
            case .data(let unlockedPdf):
                self.onProcessCompleted(forPdf: unlockedPdf)
            }
        }
    }
    
    lazy var pdfUnlockViewModel: PdfUnlockViewModel = Container.shared
        .pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncPdf: self.asyncSubject(\.asyncUnlockedPdf)))
    
    private let mergedPdf: Binding<AsyncOperation<Pdf, PdfError>>
    
    private var pendingPdfs: [Pdf] = []
    private var processedPdfs: [Pdf] = []
    
    init(params: Params) {
        self.mergedPdf = params.asyncPdf
    }
    
    func merge() {
        self.showFilePicker = true
    }
    
    func processSelectedUrls(_ urls: [URL]) {
        
        guard urls.count > 0 else {
            self.mergedPdf.wrappedValue = .init(status: .empty)
            return
        }
        
        self.pendingPdfs = urls.compactMap { Pdf(pdfUrl: $0) }
        
        self.processNextPdf()
    }
    
    private func processNextPdf() {
        guard let pdf = self.pendingPdfs.popLast() else {
            let mergedPdf = self.processedPdfs.reduce(Pdf()) { accumulatedPdf, currentPdf in
                var accumulatedPdf = accumulatedPdf
                let document = accumulatedPdf.pdfDocument
                PDFUtility.appendPdfDocument(currentPdf.pdfDocument, toPdfDocument: document)
                accumulatedPdf.updateDocument(document)
                return accumulatedPdf
            }
            self.mergedPdf.wrappedValue = AsyncOperation(status: .data(mergedPdf))
            self.processedPdfs = []
            
            self.showMergeManager = true
            
            return
        }
        
        if pdf.pdfDocument.isLocked {
            self.pdfUnlockViewModel.unlock(pdf: pdf)
        } else {
            self.onProcessCompleted(forPdf: pdf)
        }
    }
    
    private func onProcessCompleted(forPdf pdf: Pdf) {
        self.processedPdfs.append(pdf)
        self.processNextPdf()
    }
}
