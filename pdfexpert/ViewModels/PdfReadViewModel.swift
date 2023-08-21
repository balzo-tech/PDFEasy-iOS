//
//  PdfReadViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import Foundation
import Factory

extension Container {
    var pdfReadViewModel: Factory<PdfReadViewModel> {
        self { PdfReadViewModel() }
    }
}

class PdfReadViewModel: ObservableObject {
    
    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.toBeReadPdf = importedPdf
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var toBeReadPdf: Pdf? = nil
    
    @Injected(\.repository) private var repository
    @Injected(\.analyticsManager) private var analyticsManager
    
    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()
    
    func read(pdf: Pdf?) {
        if let pdf = pdf {
            self.asyncImportedPdf = .init(status: .data(pdf))
        } else {
            self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForRead)
        }
    }
}
