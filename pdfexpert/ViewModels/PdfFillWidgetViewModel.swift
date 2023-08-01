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

typealias PdfFillWidgetViewModelCallback = ((Pdf) -> ())

class PdfFillWidgetViewModel: ObservableObject {
    
    struct InputParameter {
        let pdf: Pdf
        let currentPageIndex: Int
        let onConfirm: PdfFillWidgetViewModelCallback
    }
    
    @Published var pdfDocument: PDFDocument
    @Published var pdfView: PDFView = PDFView()
    @Published var pdfCurrentPageIndex: Int
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    var unsavedChangesExist: Bool = true
    
    private var onConfirm: PdfFillWidgetViewModelCallback
    
    private var pdf: Pdf
    
    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        var pdfDocumentCopy = PDFDocument()
        if let pdfData = inputParameter.pdf.pdfDocument.dataRepresentation(), let copy = PDFDocument(data: pdfData) {
            pdfDocumentCopy = copy
        }
        self.onConfirm = inputParameter.onConfirm
        self.pdfDocument = pdfDocumentCopy
        self.pdfCurrentPageIndex = inputParameter.currentPageIndex
        self.pdfView.document = pdfDocumentCopy
        
        if let page = self.pdfView.document?.page(at: inputParameter.currentPageIndex) {
            self.pdfView.go(to: page)
        }
        
        NotificationCenter.default.addObserver(
              self,
              selector: #selector(self.handlePageChange(notification:)),
              name: Notification.Name.PDFViewPageChanged,
              object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.PDFViewPageChanged, object: nil)
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.fillWidget))
    }
    
    func onCancelButtonPressed() {
        self.analyticsManager.track(event: .fillWidgetCancelled)
    }
    
    func onConfirmButtonPressed() {
        // TODO: Check if there are changes in the annotations and propagate changes only in that case
        self.analyticsManager.track(event: .fillWidgetConfirmed)
        self.pdf.updateDocument(self.pdfDocument)
        self.onConfirm(self.pdf)
    }
    
    @objc private func handlePageChange(notification: Notification) {
        guard let currentPageindex = self.pdfView.currentPageIndex else {
            assertionFailure("Missing expected page index")
            return
        }
        self.pdfCurrentPageIndex = currentPageindex
    }
}
