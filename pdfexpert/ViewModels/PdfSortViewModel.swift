//
//  PdfSortViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 02/08/23.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfSortViewModel: ParameterFactory<PdfSortViewModel.Params, PdfSortViewModel> {
        self { PdfSortViewModel(params: $0) }
    }
}

typealias PdfSortConfirmCallback = () -> ()
typealias PdfSortCancelCallback = () -> ()

class PdfSortViewModel: ObservableObject {
    
    struct Params {
        let pdfs: Binding<[Pdf]>
        let confirmButtonText: String
        let confirmCallback: PdfSortConfirmCallback
        let cancelCallback: PdfSortCancelCallback
    }
    
    let confirmButtonText: String
    
    @Binding var pdfs: [Pdf]
    
    private let confirmCallback: PdfSortConfirmCallback
    private let cancelCallback: PdfSortCancelCallback
    
    init(params: Params) {
        self._pdfs = params.pdfs
        self.confirmButtonText = params.confirmButtonText
        self.confirmCallback = params.confirmCallback
        self.cancelCallback = params.cancelCallback
    }
    
    func confirm() {
        self.confirmCallback()
    }
    
    func cancel() {
        self.cancelCallback()
    }
}
