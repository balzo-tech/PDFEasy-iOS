//
//  PdfEditViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import Factory

extension Container {
    var pdfEditViewModel: ParameterFactory<PdfEditable, PdfEditViewModel> {
        self { PdfEditViewModel(pdfEditable: $0) }.shared
    }
}

class PdfEditViewModel: ObservableObject {
    
    @Published var pdfEditable: PdfEditable
    @Published var pdf: Pdf? = nil {
        didSet {
            // TODO: Inform the user of the save failure somehow
            try? self.repository.saveChanges()
        }
    }
    
    @Injected(\.repository) private var repository
    @Injected(\.pdfCoordinator) private var coordinator
    
    init(pdfEditable: PdfEditable) {
        self.pdfEditable = pdfEditable
    }
    
    func save() {
        guard let data = self.pdfEditable.rawData else {
            debugPrint(for: self, message: "Couldn't convert pdf document to data")
            return
        }
        self.coordinator.showViewer(pdf: Pdf(context: self.repository.pdfManagedContext, pdfData: data))
    }
}
