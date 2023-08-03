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
    @Published var showPdfSorter: Bool = false
    @Published var asyncUnlockedPdfs: AsyncOperation<[Pdf], PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let unlockedPdfs = self.asyncUnlockedPdfs.data {
                self.onUnlockCompleted(pdfs: unlockedPdfs)
                self.asyncUnlockedPdfs = .init(status: .empty)
            }
        }
    }
    
    @Published var toBeSortedPdfs: [Pdf] = []
    
    lazy var pdfUnlockViewModel: PdfUnlockViewModel = {
        Container.shared.pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfs: self.asyncSubject(\.asyncUnlockedPdfs)))
    }()
    
    private let asyncMergedPdf: Binding<AsyncOperation<Pdf, PdfError>>
    
    init(params: Params) {
        self.asyncMergedPdf = params.asyncPdf
    }
    
    func merge() {
        self.showFilePicker = true
    }
    
    func processSelectedUrls(_ urls: [URL]) {
        self.pdfUnlockViewModel.unlockPdfs(urls.compactMap { Pdf(pdfUrl: $0) })
    }
    
    func onSortedCancelled() {
        self.toBeSortedPdfs = []
        self.showPdfSorter = false
    }
    
    func onSortedConfirmed() {
        self.showPdfSorter = false
    }
    
    func onSortedCompleted() {
        if self.toBeSortedPdfs.count > 0 {
            self.mergePdfs(pdfs: self.toBeSortedPdfs)
            self.toBeSortedPdfs = []
        } else {
            self.asyncMergedPdf.wrappedValue = .init(status: .empty)
        }
    }
    
    private func onUnlockCompleted(pdfs: [Pdf]) {
        if pdfs.count > 1 {
            self.toBeSortedPdfs = pdfs
            self.showPdfSorter = true
        } else if pdfs.count == 1, let pdf = pdfs.first {
            self.asyncMergedPdf.wrappedValue = AsyncOperation(status: .data(pdf))
        } else {
            self.asyncMergedPdf.wrappedValue = .init(status: .empty)
        }
    }
    
    private func mergePdfs(pdfs: [Pdf]) {
        let mergedPdf = pdfs.reduce(Pdf()) { accumulatedPdf, currentPdf in
            var accumulatedPdf = accumulatedPdf
            let document = accumulatedPdf.pdfDocument
            PDFUtility.appendPdfDocument(currentPdf.pdfDocument, toPdfDocument: document)
            accumulatedPdf.updateDocument(document)
            return accumulatedPdf
        }
        self.asyncMergedPdf.wrappedValue = AsyncOperation(status: .data(mergedPdf))
    }
}
