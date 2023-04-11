//
//  PdfViewerViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import Factory

extension Container {
    var pdfViewerViewModel: ParameterFactory<Pdf, PdfViewerViewModel> {
        self { PdfViewerViewModel(pdf: $0) }.shared
    }
}

class PdfViewerViewModel: ObservableObject {
    
    @Published var pdf: Pdf
    @Published var pdfToBeShared: Pdf?
    @Published var monetizationShow: Bool = false
    
    @Injected(\.store) private var store
    
    init(pdf: Pdf) {
        self.pdf = pdf
    }
    
    func share() {
        if self.store.isPremium.value {
            self.pdfToBeShared = self.pdf
        } else {
            self.monetizationShow = true
        }
    }
}
