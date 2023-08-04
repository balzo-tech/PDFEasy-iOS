//
//  PdfImportMultipleViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import Foundation
import Factory
import SwiftUI
import UniformTypeIdentifiers

extension Container {
    var pdfImportMultipleViewModel: ParameterFactory<PdfImportMultipleViewModel.Params, PdfImportMultipleViewModel> {
        self { PdfImportMultipleViewModel(params: $0) }
    }
}

class PdfImportMultipleViewModel: ObservableObject {
    
    struct Params {
        let asyncPdfs: Binding<AsyncOperation<[Pdf], PdfError>>
    }
    
    @Published var loading: Bool = false
    @Published var showFilePicker: Bool = false
    
    lazy var pdfUnlockViewModel: PdfUnlockViewModel = {
        Container.shared.pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfMultipleOutput: self.asyncImportedPdfs))
    }()
    
    var importFileTypes: [UTType] = []
    
    private let asyncImportedPdfs: Binding<AsyncOperation<[Pdf], PdfError>>
    
    init(params: Params) {
        self.asyncImportedPdfs = params.asyncPdfs
    }
    
    func importPdfs(importFileTypes: [UTType]) {
        self.importFileTypes = importFileTypes
        self.showFilePicker = true
    }
    
    @MainActor
    func processSelectedUrls(_ urls: [URL]) {
        guard urls.count > 0 else {
            assertionFailure("Missing selected urls")
            self.asyncImportedPdfs.wrappedValue = .init(status: .error(.urlToPdfConversionError))
            return
        }
        
        self.loading = true
        Task {
            let task = Task<[Pdf], Never> {
                return urls.compactMap { Pdf(pdfUrl: $0) }
            }
            let pdfs = await task.value
            if pdfs.count > 0 {
                self.pdfUnlockViewModel.unlockPdfs(pdfs: pdfs)
            } else {
                self.asyncImportedPdfs.wrappedValue = .init(status: .error(.urlToPdfConversionError))
            }
            self.loading = false
        }
    }
}
