//
//  PdfFillFormViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 26/05/23.
//

import Foundation
import Factory
import PDFKit
import UIKit

extension Container {
    var pdfFillFormViewModel: ParameterFactory<PdfFillFormViewModel.InputParameter, PdfFillFormViewModel> {
        self { PdfFillFormViewModel(inputParameter: $0) }
    }
}

typealias PdfFillFormViewCallback = ((PdfEditable) -> ())

class PdfFillFormViewModel: ObservableObject {
    
    struct InputParameter {
        let pdfEditable: PdfEditable
        let currentPageIndex: Int
        let onConfirm: PdfFillFormViewCallback
    }
    
    @Published var pdfDocument: PDFDocument
    @Published var pageImages: [UIImage] = []
    @Published var pageIndex: Int = 0 {
        didSet {
            self.applyCurrentEditedTextAnnotation()
            self.editedPageIndex = nil
            
        }
    }
    @Published var annotations: [PDFAnnotation] = []
    @Published var currentTextResizableViewData: TextResizableViewData = TextResizableViewData(text: "", rect: .zero)
    @Published var editedPageIndex: Int? = nil
    
    var pageScrollingAllowed: Bool { nil == self.editedPageIndex }
    var pageViewSize: CGSize = .zero
    var shouldShowCloseWarning: Bool = false
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    private var onConfirm: PdfSignatureCallback
    
    init(inputParameter: InputParameter) {
        var pdfDocumentCopy = PDFDocument()
        if let pdfData = inputParameter.pdfEditable.pdfDocument.dataRepresentation(), let copy = PDFDocument(data: pdfData) {
            pdfDocumentCopy = copy
        }
        self.pdfDocument = pdfDocumentCopy
        
        self.onConfirm = inputParameter.onConfirm
        
        for pageIndex in 0..<self.pdfDocument.pageCount {
            if let page = self.pdfDocument.page(at: pageIndex) {
                let annotations = page.annotations.supportedAnnotations
                // Store annotations
                self.annotations.append(contentsOf: annotations)
                // Detach annotations from page
                for annotation in annotations {
                    page.removeAnnotation(annotation)
                }
                // Render page
                self.pageImages.append(page.thumbnail(of: page.bounds(for: .mediaBox).size, for: .mediaBox))
            }
        }
        
        self.pageIndex = inputParameter.currentPageIndex
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.fillForm))
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
        
        if self.pageViewSize == .zero {
            self.pageViewSize = pageViewSize
        }
        
        debugPrint(for: self, message: "Tap in: \(positionInView), for page index: \(pageIndex)")
        
        let pointInPage = Self.convertPoint(positionInView, viewSize: pageViewSize, toPage: page)
        let textAnnotations = self.annotations.filter { $0.isTextAnnotation }
        let textAnnotationsInPoint = textAnnotations.filter { $0.page == page && $0.verticalCenteredTextBounds.contains(pointInPage) }
        
        if self.editedPageIndex != nil, self.currentTextResizableViewData.rect.contains(positionInView) {
            // Tapping inside the currently selected text resizable view -> Do nothing
            return
        }
        
        if self.editedPageIndex != nil {
            // Tapping outside the currently selected text resizable view -> convert that text resizable view to text annotation
            self.applyCurrentEditedTextAnnotation()
            self.editedPageIndex = nil

            if let textAnnotation = textAnnotationsInPoint.first {
                // Tapping inside a different text annotation -> convert that text annotation to text resizable view
                let rect = Self.convertRect(textAnnotation.verticalCenteredTextBounds, viewSize: self.pageViewSize, fromPage: page)
                self.currentTextResizableViewData = TextResizableViewData(text: textAnnotation.text, rect: rect)
                self.editedPageIndex = pageIndex
                self.annotations.removeAll(where: { $0 == textAnnotation })
            }
            // Changes are applied, set the dirty flag
            self.shouldShowCloseWarning = true
        } else if let textAnnotation = textAnnotationsInPoint.first {
            // Tapping inside a text annotation -> convert that text annotation to text resizable view
            let rect = Self.convertRect(textAnnotation.verticalCenteredTextBounds, viewSize: self.pageViewSize, fromPage: page)
            self.currentTextResizableViewData = TextResizableViewData(text: textAnnotation.contents ?? "", rect: rect)
            self.editedPageIndex = pageIndex
            self.annotations.removeAll(where: { $0 == textAnnotation })
            // Nothing changes in this exact instant, but it will if the user modify the text resizable view
            // Just set the dirty flag here to keep it simple
            self.shouldShowCloseWarning = true
        } else {
            // Tapping in empty area -> create a new text resizable view
            let size = CGSize(width: 100, height: 15)
            let rect = CGRect(x: positionInView.x - (size.width / 2), y: positionInView.y - (size.height / 2), width: size.width, height: size.height)
            self.currentTextResizableViewData = TextResizableViewData(text: "Text", rect: rect)
            self.editedPageIndex = pageIndex
            // The newly created text resizable view will be added as an annotation upon confirmation
            // thus the dirty flag must be set
            self.shouldShowCloseWarning = true
        }
    }
    
    func onDeleteAnnotationPressed() {
        self.editedPageIndex = nil
        self.analyticsManager.track(event: .textAnnotationRemoved)
        // A text resizable view has been removed. If that view was associated to an existing text annotation
        // a change has been made to the original file. Just setting the dirty flag anyway to keep it simple
        self.shouldShowCloseWarning = true
    }
    
    func onConfirmButtonPressed() {
        
        if self.editedPageIndex != nil {
            self.applyCurrentEditedTextAnnotation()
        }
        
        for pageIndex in 0..<self.pdfDocument.pageCount {
            if let page = self.pdfDocument.page(at: pageIndex) {
                let pageAnnotations = self.annotations.filter { $0.page == page }
                // Attach annotations to page
                for pageAnnotation in pageAnnotations {
                    page.addAnnotation(pageAnnotation)
                }
            }
        }
        
        self.analyticsManager.track(event: .annotationsConfirmed)
        
        self.onConfirm(PdfEditable(pdfDocument: self.pdfDocument))
    }
    
    private func applyCurrentEditedTextAnnotation() {
        guard let pageIndex = self.editedPageIndex, let page = self.pdfDocument.page(at: pageIndex), !self.currentTextResizableViewData.text.isEmpty else {
            return
        }
        let bounds = Self.convertRect(self.currentTextResizableViewData.rect, viewSize: self.pageViewSize, toPage: page)
        let annotation = PDFAnnotation.create(with: self.currentTextResizableViewData.text,
                                              forBounds: bounds,
                                              textColor: .black,
                                              fontName: K.Misc.DefaultAnnotationTextFontName,
                                              withProperties: nil)
        annotation.page = page
        self.annotations.append(annotation)
        self.analyticsManager.track(event: .textAnnotationAdded)
    }
    
    static func convertPoint(_ point: CGPoint, viewSize: CGSize, toPage: PDFPage) -> CGPoint {
        let pageRect = toPage.bounds(for: .mediaBox)
        let viewRect = CGRect(origin: .zero, size: viewSize)
        return convertPoint(point, fromRect: viewRect, toRect: pageRect).getYInverted(forParentSize: pageRect.size.height)
    }

    static func convertPoint(_ point: CGPoint, viewSize: CGSize, fromPage: PDFPage) -> CGPoint {
        let pageRect = fromPage.bounds(for: .mediaBox)
        let viewRect = CGRect(origin: .zero, size: viewSize)
        return convertPoint(point.getYInverted(forParentSize: pageRect.size.height), fromRect: pageRect, toRect: viewRect)
    }
    
    static func convertRect(_ rect: CGRect, viewSize: CGSize, toPage: PDFPage) -> CGRect {
        let pageRect = toPage.bounds(for: .mediaBox)
        let viewRect = CGRect(origin: .zero, size: viewSize)
        return convertRect(rect, fromRect: viewRect, toRect: pageRect).getYInverted(forParentSize: pageRect.size.height)
    }
    
    static func convertRect(_ rect: CGRect, viewSize: CGSize, fromPage: PDFPage) -> CGRect {
        let pageRect = fromPage.bounds(for: .mediaBox)
        let viewRect = CGRect(origin: .zero, size: viewSize)
        return convertRect(rect.getYInverted(forParentSize: pageRect.size.height), fromRect: pageRect, toRect: viewRect)
    }
    
    private static func convertRect(_ rect: CGRect, fromRect: CGRect, toRect: CGRect) -> CGRect {
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let convertedTopLeft = convertPoint(topLeft, fromRect: fromRect, toRect: toRect)
        let convertedBottomRight = convertPoint(bottomRight, fromRect: fromRect, toRect: toRect)
        return CGRect(x: convertedTopLeft.x,
                      y: convertedTopLeft.y,
                      width: max(0 ,convertedBottomRight.x - convertedTopLeft.x),
                      height: max(0 ,convertedBottomRight.y - convertedTopLeft.y))
    }
    
    private static func convertPoint(_ point: CGPoint, fromRect: CGRect, toRect: CGRect) -> CGPoint {
        let x = point.x * (toRect.size.width / fromRect.size.width)
        let y = point.y * (toRect.size.height / fromRect.size.height)
        return CGPoint(x: x, y: y)
    }
}

extension Array where Element == PDFAnnotation {
    var supportedAnnotations: [PDFAnnotation] {
        self.filter { $0.isTextAnnotation }
    }
}

extension CGRect {
    func getYInverted(forParentSize parentHeight: CGFloat) -> CGRect {
        return CGRect(origin: CGPoint(x: self.origin.x, y: parentHeight-self.origin.y-self.size.height), size: self.size)
    }
}

extension CGPoint {
    func getYInverted(forParentSize parentHeight: CGFloat) -> CGPoint {
        return CGPoint(x: self.x, y: parentHeight-self.y)
    }
}
