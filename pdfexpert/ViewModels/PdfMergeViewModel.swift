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
    
    @Published var loading: Bool = false
    @Published var showPdfSorter: Bool = false
    @Published var asyncImportedPdfs: AsyncOperation<[Pdf], PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdfs = self.asyncImportedPdfs.data {
                self.onImportCompleted(pdfs: importedPdfs)
                self.asyncImportedPdfs = .init(status: .empty)
            }
        }
    }
    @Published var toBeSortedPdfs: [Pdf] = []
    
    lazy var pdfImportMultipleViewModel: PdfImportMultipleViewModel = {
        Container.shared.pdfImportMultipleViewModel(PdfImportMultipleViewModel.Params(asyncPdfs: self.asyncSubject(\.asyncImportedPdfs)))
    }()
    
    private let asyncMergedPdf: Binding<AsyncOperation<Pdf, PdfError>>
    
    init(params: Params) {
        self.asyncMergedPdf = params.asyncPdf
    }
    
    func merge() {
        self.pdfImportMultipleViewModel.importPdfs(importFileTypes: K.Misc.ImportFileTypesForMerge)
    }
    
    func onSortedCancelled() {
        self.toBeSortedPdfs = []
        self.showPdfSorter = false
    }
    
    func onSortedConfirmed() {
        self.showPdfSorter = false
    }
    
    @MainActor
    func onSortedCompleted() {
        if self.toBeSortedPdfs.count > 0 {
            self.mergePdfs(pdfs: self.toBeSortedPdfs)
            self.toBeSortedPdfs = []
        } else {
            self.asyncMergedPdf.wrappedValue = .init(status: .empty)
        }
    }
    
    private func onImportCompleted(pdfs: [Pdf]) {
        if pdfs.count > 1 {
            self.toBeSortedPdfs = pdfs
            self.showPdfSorter = true
        } else if pdfs.count == 1, let pdf = pdfs.first {
            self.asyncMergedPdf.wrappedValue = AsyncOperation(status: .data(pdf))
        } else {
            self.asyncMergedPdf.wrappedValue = .init(status: .empty)
        }
    }
    
    @MainActor
    private func mergePdfs(pdfs: [Pdf]) {
        self.loading = true
        
        Task {
            let task = Task<Pdf, Never> {
                return pdfs.reduce(Pdf()) { accumulatedPdf, currentPdf in
                    var accumulatedPdf = accumulatedPdf
                    let document = accumulatedPdf.pdfDocument
                    PDFUtility.appendPdfDocument(currentPdf.pdfDocument, toPdfDocument: document)
                    accumulatedPdf.updateDocument(document)
                    return accumulatedPdf
                }
            }
            let mergedPdf = await task.value
            self.loading = false
            self.asyncMergedPdf.wrappedValue = AsyncOperation(status: .data(mergedPdf))
        }
    }
}
