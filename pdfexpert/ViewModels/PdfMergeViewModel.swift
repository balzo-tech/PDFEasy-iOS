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
    @Published var asyncUnlockedPdfs: AsyncOperation<[Pdf], PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let unlockedPdfs = self.asyncUnlockedPdfs.data {
                self.mergePdfs(pdfs: unlockedPdfs)
                self.asyncUnlockedPdfs = .init(status: .empty)
            }
        }
    }
    
    lazy var pdfUnlockViewModel: PdfUnlockViewModel = Container.shared
        .pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfs: self.asyncSubject(\.asyncUnlockedPdfs)))
    
    private let mergedPdf: Binding<AsyncOperation<Pdf, PdfError>>
    
    init(params: Params) {
        self.mergedPdf = params.asyncPdf
    }
    
    func merge() {
        self.showFilePicker = true
    }
    
    func processSelectedUrls(_ urls: [URL]) {
        self.pdfUnlockViewModel.unlockPdfs(urls.compactMap { Pdf(pdfUrl: $0) })
    }
    
    private func mergePdfs(pdfs: [Pdf]) {
        // TODO: Allow pdf re-ordering in dedicated view
//        self.showMergeManager = true
        let mergedPdf = pdfs.reduce(Pdf()) { accumulatedPdf, currentPdf in
            var accumulatedPdf = accumulatedPdf
            let document = accumulatedPdf.pdfDocument
            PDFUtility.appendPdfDocument(currentPdf.pdfDocument, toPdfDocument: document)
            accumulatedPdf.updateDocument(document)
            return accumulatedPdf
        }
        self.mergedPdf.wrappedValue = AsyncOperation(status: .data(mergedPdf))
    }
}
