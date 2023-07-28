//
//  PdfFillWidgetViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 22/06/23.
//

import Foundation
import Factory
import PDFKit
import UIKit

extension Container {
    var pdfFillWidgetViewModel: ParameterFactory<PdfFillWidgetViewModel.InputParameter, PdfFillWidgetViewModel> {
        self { PdfFillWidgetViewModel(inputParameter: $0) }
    }
}

typealias PdfFillWidgetViewModelCallback = ((PdfEditable) -> ())

class PdfFillWidgetViewModel: ObservableObject {
    
    struct InputParameter {
        let pdfEditable: PdfEditable
        let currentPageIndex: Int
        let onConfirm: PdfFillWidgetViewModelCallback
    }
    
    @Published var pdfDocument: PDFDocument
    @Published var pdfView: PDFView = PDFView()
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    var shouldShowCloseWarning: Bool = false
    
    private var onConfirm: PdfFillWidgetViewModelCallback
    
    private var pdfEditable: PdfEditable
    
    init(inputParameter: InputParameter) {
        self.pdfEditable = inputParameter.pdfEditable
        var pdfDocumentCopy = PDFDocument()
        if let pdfData = inputParameter.pdfEditable.pdfDocument.dataRepresentation(), let copy = PDFDocument(data: pdfData) {
            pdfDocumentCopy = copy
        }
        self.onConfirm = inputParameter.onConfirm
        self.pdfDocument = pdfDocumentCopy
        self.pdfView.document = pdfDocumentCopy
        
        if let page = self.pdfView.document?.page(at: inputParameter.currentPageIndex) {
            self.pdfView.go(to: page)
        }
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.fillWidget))
    }
    
    func onCancelButtonPressed() {
        self.analyticsManager.track(event: .fillWidgetCancelled)
    }
    
    func onConfirmButtonPressed() {
        self.analyticsManager.track(event: .fillWidgetConfirmed)
        self.pdfEditable.updateDocument(self.pdfDocument)
        self.onConfirm(self.pdfEditable)
    }
}
