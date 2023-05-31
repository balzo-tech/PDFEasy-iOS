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
        self { PdfFillFormViewModel(inputParameter: $0) }.shared
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
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    private var onConfirm: PdfSignatureCallback
    
    init(inputParameter: InputParameter) {
        self.pdfDocument = inputParameter.pdfEditable.pdfDocument.copy() as! PDFDocument
        
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
        let annotationsInPoint = self.annotations.filter { $0.page == page && $0.bounds.contains(pointInPage) }
        let textAnnotations = annotationsInPoint.compactMap { $0 as? TextAnnotation }
        
        if self.editedPageIndex != nil, self.currentTextResizableViewData.rect.contains(positionInView) {
            return
        }
        
        if self.editedPageIndex != nil {
            self.applyCurrentEditedTextAnnotation()
            self.editedPageIndex = nil

            if let textAnnotation = textAnnotations.first {
                let rect = Self.convertRect(textAnnotation.bounds, viewSize: self.pageViewSize, fromPage: page)
                self.currentTextResizableViewData = TextResizableViewData(text: textAnnotation.text, rect: rect)
                self.editedPageIndex = pageIndex
                self.annotations.removeAll(where: { $0 == textAnnotation })
            }
        } else if let textAnnotation = textAnnotations.first {
            let rect = Self.convertRect(textAnnotation.bounds, viewSize: self.pageViewSize, fromPage: page)
            self.currentTextResizableViewData = TextResizableViewData(text: textAnnotation.contents ?? "", rect: rect)
            self.editedPageIndex = pageIndex
            self.annotations.removeAll(where: { $0 == textAnnotation })
        } else {
//            let size = CGSize(width: 300, height: 200)
            let size = CGSize(width: 100, height: 15)
            let rect = CGRect(x: positionInView.x - (size.width / 2), y: positionInView.y - (size.height / 2), width: size.width, height: size.height)
            self.currentTextResizableViewData = TextResizableViewData(text: "Text", rect: rect)
            self.editedPageIndex = pageIndex
        }
    }
    
    func onDeleteAnnotationPressed() {
        self.editedPageIndex = nil
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
        self.onConfirm(PdfEditable(pdfDocument: self.pdfDocument))
    }
    
    func onCancelButtonPressed() {}
    
    private func applyCurrentEditedTextAnnotation() {
        guard let pageIndex = self.editedPageIndex, let page = self.pdfDocument.page(at: pageIndex), !self.currentTextResizableViewData.text.isEmpty else {
            return
        }
        let bounds = Self.convertRect(self.currentTextResizableViewData.rect, viewSize: self.pageViewSize, toPage: page)
        let fontSize = (K.Misc.DefaultAnnotationTextFontSize * K.Misc.PdfPageSize.width) / UIScreen.main.bounds.width
        let annotation = TextAnnotation(with: self.currentTextResizableViewData.text,
                                        forBounds: bounds,
                                        textColor: .black,
                                        fontSize: fontSize,
                                        fontFamilyName: K.Misc.DefaultAnnotationTextFontName,
                                        withProperties: nil)
        annotation.page = page
        self.annotations.append(annotation)
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
        self.compactMap { $0 as? TextAnnotation }
    }
}

//class PdfFillFormViewModel: ObservableObject {
//
//    struct InputParameter {
//        let pdfEditable: PdfEditable
//        let currentPageIndex: Int
//        let onConfirm: PdfFillFormViewCallback
//    }
//
//    @Published var pdfView: PDFView = PDFView()
//    @Published var pdfEditable: PdfEditable
//    @Published var selectedAnnotationViewRect: CGRect = .zero
//    @Published var selectedAnnotationColor: UIColor = .black
//    @Published var selectedTextAnnotationText: String = ""
//    @Published var selectedTextAnnotationFontFamilyName: String? = nil
//    @Published var textAnnotationSelected: Bool = false {
//        didSet {
//            print("PdfFillFormViewModel - textAnnotationSelected: \(self.textAnnotationSelected)")
//        }
//    }
//
//    var selectedTextAnnotation: TextAnnotation? {
//        guard self.textAnnotationSelected,
//              self.selectedAnnotationViewRect != .zero,
//              !self.selectedTextAnnotationText.isEmpty,
//              let page = self.pdfView.currentPage else {
//            return nil
//        }
//        return TextAnnotation(with: selectedTextAnnotationText,
//                              forBounds: self.pdfView.convert(self.selectedAnnotationViewRect, to: page),
//                              textColor: self.selectedAnnotationColor,
//                              fontFamilyName: self.selectedTextAnnotationFontFamilyName,
//                              withProperties: nil)
//    }
//
//    var pageScrollingAllowed: Bool { nil == self.selectedTextAnnotation }
//
//
//    @Injected(\.analyticsManager) private var analyticsManager
//
//    private var originalAnnotations: [PDFAnnotation] = []
//    private var onConfirm: PdfSignatureCallback
//
//    init(inputParameter: InputParameter) {
//        self.pdfEditable = inputParameter.pdfEditable
//
//        self.onConfirm = inputParameter.onConfirm
//        self.pdfView.document = inputParameter.pdfEditable.pdfDocument
//        if let page = inputParameter.pdfEditable.pdfDocument.page(at: inputParameter.currentPageIndex) {
//            self.pdfView.go(to: page)
//        }
//
//        for pageIndex in 0..<inputParameter.pdfEditable.pdfDocument.pageCount {
//            if let page = inputParameter.pdfEditable.pdfDocument.page(at: pageIndex) {
//                self.originalAnnotations.append(contentsOf: page.annotations.map { $0.copy() as! PDFAnnotation })
//            }
//        }
//
////        NotificationCenter.default.addObserver(forName: Notification.Name.PDFViewAnnotationHit, object: nil, queue: nil) { [weak self] notification in
////            self?.selectedTextAnnotation = notification.userInfo?["PDFAnnotationHit"] as? TextAnnotation
////        }
//    }
//
//    func onAppear() {
//        self.analyticsManager.track(event: .reportScreen(.fillForm))
//    }
//
//    func tapOnPdfView(positionInView: CGPoint) {
//        guard let currentPage = self.pdfView.currentPage else {
//            return
//        }
//
//        let pointInPage = self.pdfView.convert(positionInView, to: currentPage)
//        let annotationsInPoint = currentPage.annotations.filter { $0.bounds.contains(pointInPage) }
//        let textAnnotations = annotationsInPoint.compactMap { $0 as? TextAnnotation }
//
////        if let selectedTextAnnotation = self.selectedTextAnnotation {
////            currentPage.addAnnotation(selectedTextAnnotation)
////            self.textAnnotationSelected = false
////
////            if let textAnnotation = textAnnotations.first {
////                currentPage.removeAnnotation(textAnnotation)
////                self.selectedAnnotationViewRect = self.pdfView.convert(textAnnotation.bounds, from: currentPage)
////                self.selectedTextAnnotationText = textAnnotation.text
////                self.textAnnotationSelected = true
////            }
////        } else if let textAnnotation = textAnnotations.first {
////            currentPage.removeAnnotation(textAnnotation)
////            self.selectedAnnotationViewRect = self.pdfView.convert(textAnnotation.bounds, from: currentPage)
////            self.selectedTextAnnotationText = textAnnotation.text
////            self.textAnnotationSelected = true
////        } else {
////            let size = CGSize(width: 100, height: 50)
////            let rect = CGRect(x: positionInView.x - (size.width / 2), y: positionInView.y - (size.height / 2), width: size.width, height: size.height)
////            self.selectedAnnotationViewRect = rect
////            self.selectedTextAnnotationText = "Prova!"
////            self.textAnnotationSelected = true
////            self.textAnnotationSelected = false
////        }
//
//        if nil == textAnnotations.first {
//            let size = CGSize(width: 200, height: 50)
//            let rect = CGRect(x: positionInView.x - (size.width / 2), y: positionInView.y - (size.height / 2), width: size.width, height: size.height)
//            let annotation = TextAnnotation(with: "Prova!",
//                                           forBounds: self.pdfView.convert(rect, to: currentPage),
//                                           textColor: self.selectedAnnotationColor,
//                                           fontFamilyName: self.selectedTextAnnotationFontFamilyName,
//                                           withProperties: nil)
//
//            currentPage.addAnnotation(annotation)
//        }
//    }
//
//    func onDeleteAnnotationPressed() {
//        if let selectedTextAnnotation = self.selectedTextAnnotation {
//            self.pdfView.currentPage?.removeAnnotation(selectedTextAnnotation)
//        }
//    }
//
//    func onConfirmButtonPressed() {
//        // The selected annotation is removed from document, to prevent overlap between editing UI and the real annotation.
//        // So, if the user confirm and quit, the selected annotation must be readded.
//        if let selectedTextAnnotation = self.selectedTextAnnotation {
//            self.pdfView.currentPage?.addAnnotation(selectedTextAnnotation)
//        }
//        self.onConfirm(self.pdfEditable)
//    }
//
//    func onCancelButtonPressed() {
//        self.resetAnnotations()
//    }
//
//    private func resetAnnotations() {
//        for pageIndex in 0..<self.pdfEditable.pdfDocument.pageCount {
//            if let page = self.pdfEditable.pdfDocument.page(at: pageIndex) {
//                let toCancelledAnnotations = page.annotations
//                for toCancelledAnnotation in toCancelledAnnotations {
//                    page.removeAnnotation(toCancelledAnnotation)
//                }
//                self.originalAnnotations.filter { $0.page == page }.forEach { originalAnnotation in
//                    page.addAnnotation(originalAnnotation)
//                }
//            }
//        }
//    }
//
//    private func saveSelectedAnnotation() {
//        if let selectedTextAnnotation = self.selectedTextAnnotation {
//            self.pdfView.currentPage?.addAnnotation(selectedTextAnnotation)
//        }
//    }
//}


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
