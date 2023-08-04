//
//  PdfImportViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import Foundation
import Factory
import SwiftUI
import UniformTypeIdentifiers

extension Container {
    var pdfImportViewModel: ParameterFactory<PdfImportViewModel.Params, PdfImportViewModel> {
        self { PdfImportViewModel(params: $0) }
    }
}

class PdfImportViewModel: ObservableObject {
    
    struct Params {
        let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    }
    
    @Published var loading: Bool = false
    @Published var showFilePicker: Bool = false
    
    lazy var pdfUnlockViewModel: PdfUnlockViewModel = {
        Container.shared.pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfSingleOutput: self.asyncImportedPdf))
    }()
    
    var importFileTypes: [UTType] = []
    
    private let asyncImportedPdf: Binding<AsyncOperation<Pdf, PdfError>>
    
    init(params: Params) {
        self.asyncImportedPdf = params.asyncPdf
    }
    
    func importPdf(importFileTypes: [UTType]) {
        self.importFileTypes = importFileTypes
        self.showFilePicker = true
    }
    
    @MainActor
    func processSelectedUrls(_ urls: [URL]) {
        guard let url = urls.first else {
            assertionFailure("Missing selected url")
            self.asyncImportedPdf.wrappedValue = .init(status: .error(.urlToPdfConversionError))
            return
        }
        
        self.loading = true
        Task {
            let task = Task<Pdf?, Never> {
                return Pdf(pdfUrl: url)
            }
            if let pdf = await task.value {
                self.pdfUnlockViewModel.unlockPdf(pdf: pdf)
            } else {
                self.asyncImportedPdf.wrappedValue = .init(status: .error(.urlToPdfConversionError))
            }
            self.loading = false
        }
    }
}
