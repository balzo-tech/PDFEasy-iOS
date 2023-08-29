//
//  PdfSignatureViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 10/05/23.
//

import Foundation
import Factory
import PDFKit
import UIKit
import Combine

extension Container {
    var pdfSignatureViewModel: ParameterFactory<PdfSignatureViewModel.InputParameter, PdfSignatureViewModel> {
        self { PdfSignatureViewModel(inputParameter: $0) }
    }
}

typealias PdfSignatureCallback = ((Pdf) -> ())

class PdfSignatureViewModel: ObservableObject {
    
    struct InputParameter {
        let pdf: Pdf
        let currentPageIndex: Int
        let onConfirm: PdfSignatureCallback
    }
    
    @Published var pdfDocument: PDFDocument
    @Published var pageImages: [UIImage]
    @Published var pageIndex: Int
    @Published var editedPageIndex: Int? = nil
    @Published var annotations: [PDFAnnotation]
    @Published var signatureRect: CGRect = .zero
    @Published var signatureImage: UIImage? = nil
    
    var pageViewSize: CGSize = .zero
    var unsavedChangesExist: Bool = false
    
    // Used only to perform point and rect conversions from view space to page space and viceversa
    // A dedicated PDFView for each page is needed, because changing page on the fly based on the
    // needed page appears not to be done instantly, giving wrong results.
    // This way we achieve correctness but at the cost of an increased memory consumption.
    private let pdfViews: [PDFView]
    
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.pdfSignaturePrioviderFlow) var pdfSignaturePrioviderFlow
    
    private var onConfirm: PdfSignatureCallback
    private var pdf: Pdf
    private var isReplacing: Bool = false
    
    private var cancelBag = Set<AnyCancellable>()
    
    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        var pdfDocumentCopy = PDFDocument()
        if let pdfData = inputParameter.pdf.pdfDocument.dataRepresentation(), let copy = PDFDocument(data: pdfData) {
            pdfDocumentCopy = copy
        }
        self.pdfDocument = pdfDocumentCopy
        
        self.onConfirm = inputParameter.onConfirm
        
        var pdfViews: [PDFView] = []
        var annotationLists: [PDFAnnotation] = []
        var pageImages: [UIImage] = []
        for pageIndex in 0..<pdfDocumentCopy.pageCount {
            if let page = pdfDocumentCopy.page(at: pageIndex) {
                let annotations = page.annotations.signatureAnnotations
                // Store annotations
                annotationLists.append(contentsOf: annotations)
                // Detach annotations from page
                for annotation in annotations {
                    page.removeAnnotation(annotation)
                }
                // Render page
                pageImages.append(page.thumbnail(of: page.bounds(for: .mediaBox).size, for: .mediaBox))
                
                let pdfView = PDFView()
                pdfView.document = pdfDocumentCopy
                pdfView.autoScales = true
                pdfView.displayMode = .singlePage
                pdfView.go(to: page)
                pdfViews.append(pdfView)
            }
        }
        self.annotations = annotationLists
        self.pageImages = pageImages
        self.pdfViews = pdfViews
        
        self.pageIndex = inputParameter.currentPageIndex
        
        self.$pageIndex
            .sink { [weak self] _ in
                self?.applyCurrentEditedAnnotation()
            }.store(in: &self.cancelBag)
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.signature))
    }
    
    func getAnnotations(forPageIndex pageIndex: Int) -> [PDFAnnotation] {
        guard let page = self.pdfDocument.page(at: pageIndex) else {
            return []
        }
        return self.annotations
            .filter { $0.page == page }
    }
    
    func tapOnPdfView(positionInView: CGPoint, pageIndex: Int, pageViewSize: CGSize) {
        guard let page = self.pdfDocument.page(at: pageIndex) else {
            return
        }
        
        self.pageViewSize = pageViewSize
        
        let pointInPage = self.convertPoint(positionInView, viewSize: pageViewSize, toPage: page)
        let annotationsInPoint = self.annotations.filter { $0.page == page && $0.bounds.contains(pointInPage) }
        
        if self.signatureImage != nil, self.signatureRect.contains(positionInView) {
            // Tapping inside the currently selected image resizable view -> Do nothing
            return
        }
        
        if self.signatureImage != nil {
            // Tapping outside the currently selected image resizable view -> convert that image resizable view to signature annotation
            self.applyCurrentEditedAnnotation()

            if let annotationInPoint = annotationsInPoint.first {
                // Tapping inside a different signature annotation -> convert that signature annotation to image resizable view
                self.convertAnnotationToView(annotation: annotationInPoint,
                                             pageIndex: pageIndex)
            }
            // Changes are applied, set the dirty flag
            self.unsavedChangesExist = true
        } else if let annotationInPoint = annotationsInPoint.first {
            // Tapping inside a signature annotation -> convert that signature annotation to image resizable view
            self.convertAnnotationToView(annotation: annotationInPoint,
                                         pageIndex: pageIndex)
            // Nothing changes in this exact instant, but it will if the user changes the image of the signature
            // Just set the dirty flag here to keep it simple
            self.unsavedChangesExist = true
        } else {
            // Tapping in empty area -> start the signature creation flow
            self.editedPageIndex = pageIndex
            self.startSignatureSelectionFlow(isReplacing: false)
        }
    }
    
    func onDeleteAnnotationPressed() {
        self.signatureImage = nil
        self.editedPageIndex = nil
        self.analyticsManager.track(event: .signatureRemoved)
        // A image resizable view has been removed. If that view was associated to an existing signature annotation
        // a change has been made to the original file. Just setting the dirty flag anyway to keep it simple.
        self.unsavedChangesExist = true
    }
    
    func onReplaceAnnotationPressed() {
        self.startSignatureSelectionFlow(isReplacing: true)
    }
    
    func onConfirmButtonPressed() {
        self.applyCurrentEditedAnnotation()
        
        if self.unsavedChangesExist {
            for pageIndex in 0..<self.pdfDocument.pageCount {
                if let page = self.pdfDocument.page(at: pageIndex) {
                    let pageAnnotations = self.annotations.filter { $0.page == page }
                    // Attach annotations to page
                    for pageAnnotation in pageAnnotations {
                        page.addAnnotation(pageAnnotation)
                    }
                }
            }
            self.pdf.updateDocument(self.pdfDocument)
            self.onConfirm(self.pdf)
        }
        
        self.analyticsManager.track(event: .signaturesConfirmed)
    }
    
    private func applyCurrentEditedAnnotation() {
        if let signatureImage = self.signatureImage,
           let pageIndex = self.editedPageIndex,
           let page = self.pdfDocument.page(at: pageIndex) {
            let bounds = self.convertRect(self.signatureRect, viewSize: self.pageViewSize, toPage: page)
            let annotation = PDFAnnotation.createSignature(with: signatureImage, forBounds: bounds)
            annotation.page = page
            self.annotations.append(annotation)
            self.unsavedChangesExist = true
            self.analyticsManager.track(event: .signatureAdded)
        }
        self.signatureImage = nil
        self.editedPageIndex = nil
    }
    
    private func convertAnnotationToView(annotation: PDFAnnotation,
                                         pageIndex: Int) {
        guard let page = self.pdfDocument.page(at: pageIndex) else {
            assertionFailure("Missing page with given page index")
            return
        }
        
        self.signatureRect = self.convertRect(annotation.bounds, viewSize: self.pageViewSize, fromPage: page)
        self.signatureImage = annotation.image
        self.annotations.removeAll(where: { $0 == annotation })
        self.editedPageIndex = pageIndex
    }
    
    func startSignatureSelectionFlow(isReplacing: Bool) {
        self.isReplacing = isReplacing
        self.pdfSignaturePrioviderFlow.startFlow { [weak self] signatureImage in
            self?.onSignatureSelected(signatureImage: signatureImage)
        }
    }
    
    func onSignatureSelected(signatureImage: UIImage) {
        guard let page = self.pdfDocument.page(at: self.pageIndex) else {
            assertionFailure("Missing page with given page index")
            return
        }
        guard let pdfView = self.getPdfView(viewSize: self.pageViewSize, page: page) else {
            assertionFailure("Missing page view with given page")
            return
        }
        self.signatureImage = signatureImage
        if !self.isReplacing {
            self.signatureRect = CGRect(origin: CGPoint(x: pdfView.bounds.size.width * 0.5 - signatureImage.size.width / 2,
                                                        y: pdfView.bounds.size.height * 0.5 - signatureImage.size.height / 2) ,
                                        size: signatureImage.size)
        }
        // The newly created image resizable view will be added as a signature annotation upon confirmation
        // thus the dirty flag must be set
        self.unsavedChangesExist = true
    }
    
    func convertPoint(_ point: CGPoint, viewSize: CGSize, toPage: PDFPage) -> CGPoint {
        guard let pdfView = self.getPdfView(viewSize: viewSize, page: toPage) else {
            return .zero
        }
        return pdfView.convert(point, to: toPage)
    }

    func convertPoint(_ point: CGPoint, viewSize: CGSize, fromPage: PDFPage) -> CGPoint {
        guard let pdfView = self.getPdfView(viewSize: viewSize, page: fromPage) else {
            return .zero
        }
        return pdfView.convert(point, from: fromPage)
    }
    
    func convertRect(_ rect: CGRect, viewSize: CGSize, toPage: PDFPage) -> CGRect {
        guard let pdfView = self.getPdfView(viewSize: viewSize, page: toPage) else {
            return .zero
        }
        return pdfView.convert(rect, to: toPage)
    }
    
    func convertRect(_ rect: CGRect, viewSize: CGSize, fromPage: PDFPage) -> CGRect {
        guard let pdfView = self.getPdfView(viewSize: viewSize, page: fromPage) else {
            return .zero
        }
        return pdfView.convert(rect, from: fromPage)
    }
    
    private func getPdfView(viewSize: CGSize, page: PDFPage) -> PDFView? {
        guard let pdfView = self.pdfViews.first(where: { $0.currentPage == page }) else {
            assertionFailure("Missing PdfView with given page")
            return nil
        }
        pdfView.frame = CGRect(origin: .zero, size: viewSize)
        return pdfView
    }
}

fileprivate extension Array where Element == PDFAnnotation {
    var signatureAnnotations: [PDFAnnotation] {
        self.filter { $0.isSignatureAnnotation }
    }
}
