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

typealias PdfFillFormViewCallback = ((Pdf) -> ())

class PdfFillFormViewModel: ObservableObject {
    
    struct InputParameter {
        let pdf: Pdf
        let currentPageIndex: Int
        /// See the note in `PdfSignatureViewModel`: an annotation to open for
        /// editing, matched by position because this tool copies the document.
        var annotationToEdit: PDFAnnotation? = nil
        let onConfirm: PdfFillFormViewCallback
    }
    
    @Published var pdfDocument: PDFDocument
    @Published var pageImages: [UIImage]
    @Published var pageIndex: Int {
        didSet {
            self.applyCurrentEditedTextAnnotation()
            self.editedPageIndex = nil
        }
    }
    @Published var annotations: [PDFAnnotation]
    @Published var currentTextResizableViewData: TextResizableViewData = TextResizableViewData(text: "", rect: .zero)
    @Published var editedPageIndex: Int? = nil
    @Published var showSuggestedFields: Bool = false {
        didSet {
            if !self.showSuggestedFields {
                self.refreshSuggestedFields()
            }
        }
    }
    @Published var suggestedFields: SuggestedFields? = nil
    /// Colour and face for the text being placed. Kept between one box and the
    /// next: filling a form means writing the same kind of thing several times.
    @Published var style: TextAnnotationStyle = TextAnnotationStyle()

    var pageViewSize: CGSize = .zero
    /// The annotation the editor asked to edit, waiting for the view's size.
    private var pendingEdit: (pageIndex: Int, bounds: CGRect)? = nil
    var unsavedChangesExist: Bool = false
    
    // Used only to perform point and rect conversions from view space to page space and viceversa
    // A dedicated PDFView for each page is needed, because changing page on the fly based on the
    // needed page appears not to be done instantly, giving wrong results.
    // This way we achieve correctness but at the cost of an increased memory consumption.
    private let pdfViews: [PDFView]
    
    @Injected(\.analyticsManager) private var analyticsManager
    private let repository = resolve(\.repository)
    
    private var onConfirm: PdfFillFormViewCallback
    
    private var pdf: Pdf
    
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
                let annotations = page.annotations.supportedAnnotations
                // Store annotations
                annotationLists.append(contentsOf: annotations)
                // Detach annotations from page, then hand each one its page back.
                // See the note in `PdfSignatureViewModel`: `removeAnnotation`
                // clears `annotation.page`, and the tap that reopens an existing
                // annotation for editing matches on exactly that.
                for annotation in annotations {
                    page.removeAnnotation(annotation)
                    annotation.page = page
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

        // See `PdfSignatureViewModel`: the annotation the editor tapped belongs to
        // its own document, so it is matched again by page and position.
        if let target = inputParameter.annotationToEdit, let page = target.page {
            let index = inputParameter.pdf.pdfDocument.index(for: page)
            if index != NSNotFound {
                self.pendingEdit = (pageIndex: index, bounds: target.bounds)
                self.pageIndex = index
            }
        }

        self.refreshSuggestedFields()
    }

    /// The view reporting its page size — the first moment it is known, and where
    /// an annotation the editor asked to edit is turned into an editable box.
    func onPageAppeared(size: CGSize, pageIndex: Int) {
        if self.pageViewSize == .zero { self.pageViewSize = size }
        guard let pending = self.pendingEdit,
              pending.pageIndex == pageIndex,
              let page = self.pdfDocument.page(at: pageIndex) else { return }
        self.pendingEdit = nil
        guard let annotation = self.annotations.first(where: {
            $0.isTextAnnotation && $0.page == page && $0.bounds.isNearlyEqual(to: pending.bounds)
        }) else { return }
        let rect = self.convertRect(annotation.verticalCenteredTextBounds,
                                    viewSize: self.pageViewSize,
                                    fromPage: page)
        self.currentTextResizableViewData = TextResizableViewData(text: annotation.contents ?? "", rect: rect)
        self.editedPageIndex = pageIndex
        self.annotations.removeAll(where: { $0 == annotation })
        self.unsavedChangesExist = true
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
        
        let pointInPage = self.convertPoint(positionInView, viewSize: pageViewSize, toPage: page)
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
                let rect = self.convertRect(textAnnotation.verticalCenteredTextBounds, viewSize: self.pageViewSize, fromPage: page)
                self.currentTextResizableViewData = TextResizableViewData(text: textAnnotation.text, rect: rect)
                self.editedPageIndex = pageIndex
                self.annotations.removeAll(where: { $0 == textAnnotation })
            }
            // Changes are applied, set the dirty flag
            self.unsavedChangesExist = true
        } else if let textAnnotation = textAnnotationsInPoint.first {
            // Tapping inside a text annotation -> convert that text annotation to text resizable view
            let rect = self.convertRect(textAnnotation.verticalCenteredTextBounds, viewSize: self.pageViewSize, fromPage: page)
            self.currentTextResizableViewData = TextResizableViewData(text: textAnnotation.contents ?? "", rect: rect)
            self.editedPageIndex = pageIndex
            self.annotations.removeAll(where: { $0 == textAnnotation })
            // Nothing changes in this exact instant, but it will if the user modify the text resizable view
            // Just set the dirty flag here to keep it simple
            self.unsavedChangesExist = true
        } else {
            // Tapping in empty area -> create a new text resizable view
            let size = CGSize(width: 100, height: 15)
            let rect = CGRect(x: positionInView.x - (size.width / 2), y: positionInView.y - (size.height / 2), width: size.width, height: size.height)
            self.currentTextResizableViewData = TextResizableViewData(text: "", rect: rect)
            self.editedPageIndex = pageIndex
            // The newly created text resizable view will be added as an annotation upon confirmation
            // thus the dirty flag must be set
            self.unsavedChangesExist = true
        }
    }
    
    func onDeleteAnnotationPressed() {
        self.editedPageIndex = nil
        self.analyticsManager.track(event: .textAnnotationRemoved)
        // A text resizable view has been removed. If that view was associated to an existing text annotation
        // a change has been made to the original file. Just setting the dirty flag anyway to keep it simple
        self.unsavedChangesExist = true
    }
    
    /// A− / A+ from the bar. The font is grown to fill the box, so the size of the
    /// text *is* the size of the box: scaling it around its own centre leaves the
    /// text where it was put and only changes how big it is.
    @MainActor
    func scaleEditedText(by factor: CGFloat) {
        guard self.editedPageIndex != nil else { return }
        let rect = self.currentTextResizableViewData.rect
        guard rect.width > 0, rect.height > 0 else { return }
        let width = max(Self.minimumTextSize.width,
                        min(rect.width * factor, self.pageViewSize.width))
        let height = max(Self.minimumTextSize.height,
                         min(rect.height * factor, self.pageViewSize.height))
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        var scaled = CGRect(x: centre.x - width / 2,
                            y: centre.y - height / 2,
                            width: width,
                            height: height)
        // Keep it on the page: growing something near an edge should push it back
        // in rather than half of it off.
        if self.pageViewSize != .zero {
            scaled.origin.x = min(max(0, scaled.origin.x), max(0, self.pageViewSize.width - width))
            scaled.origin.y = min(max(0, scaled.origin.y), max(0, self.pageViewSize.height - height))
        }
        self.currentTextResizableViewData = TextResizableViewData(
            text: self.currentTextResizableViewData.text,
            rect: scaled
        )
    }

    private static let minimumTextSize = CGSize(width: 24, height: 14)

    func onConfirmButtonPressed() {
        if self.editedPageIndex != nil {
            self.applyCurrentEditedTextAnnotation()
        }
        
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
        
        self.analyticsManager.track(event: .annotationsConfirmed)
    }
    
    func onSuggestedFieldsButtonPressed() {
        self.showSuggestedFields = true
    }
    
    private func refreshSuggestedFields() {
        self.suggestedFields = try? self.repository.loadSuggestedFields()
    }
    
    private func applyCurrentEditedTextAnnotation() {
        guard let pageIndex = self.editedPageIndex, let page = self.pdfDocument.page(at: pageIndex), !self.currentTextResizableViewData.text.isEmpty else {
            return
        }
        let bounds = self.convertRect(self.currentTextResizableViewData.rect, viewSize: self.pageViewSize, toPage: page)
        let annotation = PDFAnnotation.create(with: self.currentTextResizableViewData.text,
                                              forBounds: bounds,
                                              textColor: self.style.color.uiColor,
                                              fontName: self.style.font.fontName,
                                              withProperties: nil)
        annotation.page = page
        self.annotations.append(annotation)
        self.unsavedChangesExist = true
        self.analyticsManager.track(event: .textAnnotationAdded)
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
