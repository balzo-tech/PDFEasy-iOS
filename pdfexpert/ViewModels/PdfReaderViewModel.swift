//
//  PdfReaderViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import Foundation
import Factory
import SwiftUI
import PDFKit

extension Container {
    var pdfReaderViewModel: ParameterFactory<PdfReaderViewModel.Params, PdfReaderViewModel> {
        self { PdfReaderViewModel(params: $0) }
    }
}

/// The three text markups the reader can apply. Kept as an app-level type rather than
/// passing `PDFAnnotationSubtype` around so the UI, analytics and persistence all agree
/// on the same closed set.
enum PdfAnnotationType: String, CaseIterable, Identifiable {
    case highlight
    case underline
    case strikethrough

    var id: Self { self }

    var subtype: PDFAnnotationSubtype {
        switch self {
        case .highlight: return .highlight
        case .underline: return .underline
        case .strikethrough: return .strikeOut
        }
    }

    var systemImageName: String {
        switch self {
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        }
    }

    var displayName: String {
        switch self {
        case .highlight: return String(localized: "Highlight")
        case .underline: return String(localized: "Underline")
        case .strikethrough: return String(localized: "Strikethrough")
        }
    }
}

class PdfReaderViewModel: ObservableObject {

    struct Params {
        let pdf: Pdf
        /// Called after a successful save, so the presenting screen can refresh.
        var onSaved: ((Pdf) -> Void)? = nil
    }

    @Published var pages: [AttributedString?] = []
    @Published var pageIndex: Int = 0 {
        didSet {
            if let page = self.pdfView.document?.page(at: self.pageIndex) {
                self.pdfView.go(to: page)
            }
        }
    }
    
    @Published var pdfView: PDFView = PDFView()
    
    @Published var textMode: Bool = false
    @Published var fontScale: CGFloat = K.Misc.PdfReaderDefaultFontScale
    
    @Published var pageThumbnails: AsyncItem<[UIImage?]> = .empty
    @Published var showPageSelection: Bool = false
    
    @Published var pageImages: AsyncItemFailable<[PdfImage], SharedUnderlyingError> = .empty
    @Published var showPageImages: Bool = false

    // MARK: Annotations

    /// While on, the reader stops being read-only and taps apply the selected markup.
    @Published private(set) var annotationMode: Bool = false
    @Published var annotationType: PdfAnnotationType = .highlight
    @Published var annotationColor: Color = PdfReaderViewModel.annotationColors[0]
    @Published private(set) var hasUnsavedAnnotations: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var unsavedChangesAlertShow: Bool = false
    @Published var saveErrorShow: Bool = false

    static let annotationColors: [Color] = [.yellow, .green, .blue, .pink]

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.repository) private var repository

    var filename: String { self.pdf.filename }
    var pageCount: Int { self.pdf.pageCount }

    private var pdf: Pdf
    private let onSaved: ((Pdf) -> Void)?
    /// Markup added in this session, newest last — backs the undo.
    private var addedAnnotations: [(page: PDFPage, annotation: PDFAnnotation)] = []

    init(params: Params) {
        self.pdf = params.pdf
        self.onSaved = params.onSaved
        self.updatePages()

        var pdfDocumentCopy = PDFDocument()
        if let pdfData = params.pdf.pdfDocument.dataRepresentation(), let copy = PDFDocument(data: pdfData) {
            pdfDocumentCopy = copy
        }
        // Existing annotations start read-only: the reader is a reader until the user
        // deliberately turns annotation mode on.
        pdfDocumentCopy.forEach{ $0.annotations.forEach { $0.isReadOnly = true } }
        self.pdfView.document = pdfDocumentCopy
        self.pdfView.displayDirection = .horizontal
        
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
        self.analyticsManager.track(event: .reportScreen(.reader))
        #if DEBUG
        // debugReaderSheet=pages opens the page picker, which otherwise needs a tap
        // in the reader's own menu:
        //   xcrun simctl spawn booted defaults write <bundle-id> debugReaderSheet -string pages
        if UserDefaults.standard.string(forKey: "debugReaderSheet") == "pages" {
            DispatchQueue.main.async { self.presentPageSelection() }
        }
        #endif
    }
    
    func updatePages() {
        self.pages = self.pdf.map { $0.attributedString?.getPdfBodyText(fontScale: self.fontScale) }
    }
    
    @MainActor
    func presentPageSelection() {
        if self.pageThumbnails.hasData {
            self.showPageSelection = true
        } else {
            self.pageThumbnails = .loading(.undeterminedProgress)
            Task {
                let task = Task<[UIImage?], Never> {
                    return PDFUtility.generatePdfThumbnails(pdfDocument: self.pdf.pdfDocument,
                                                            size: K.Misc.ThumbnailSize)
                }
                self.pageThumbnails = .data(await task.value)
                self.showPageSelection = true
            }
        }
    }
    
    @MainActor
    func presentPageImages() {
        guard self.pageIndex < self.pdf.pageCount else {
            self.pageImages = .error(.unknownError)
            return
        }
        
        let page = self.pdf[self.pageIndex]
        
        self.pageImages = .loading(.undeterminedProgress)
        do {
            var images: [PdfImage] = []
            try extractImages(from: page) { image, name in
                let uiImage: UIImage? = {
                    switch image {
                    case .jpg(let data):
                        return UIImage(data: data)
                    case .raw(let cgImage):
                        return UIImage(cgImage: cgImage)
                    }
                }()
                if let uiImage {
                    images.append(PdfImage(image: uiImage, caption: name))
                }
            }
            self.pageImages = .data(images)
            self.showPageImages = true
        } catch {
            self.pageImages = .error(SharedUnderlyingError.convertError(fromError: error))
        }
    }
    
    func switchTextMode() {
        self.textMode = !self.textMode
    }

    // MARK: - Annotation mode

    /// Premium-gated on entry (pattern shared with OCR): nobody should annotate for ten
    /// minutes and only then meet the paywall.
    @MainActor
    func toggleAnnotationMode() {
        if self.annotationMode {
            self.setAnnotationMode(false)
            return
        }
        if self.store.isPremium.value {
            self.setAnnotationMode(true)
        } else {
            self.monetizationShow = true
        }
    }

    @MainActor
    func onMonetizationClose() {
        if self.store.isPremium.value {
            self.setAnnotationMode(true)
        }
    }

    @MainActor
    private func setAnnotationMode(_ enabled: Bool) {
        self.annotationMode = enabled
        // Text mode has no annotations to speak of, so entering annotation mode also
        // brings the document view back.
        if enabled {
            self.textMode = false
        }
        self.pdfView.document?.forEach { page in
            page.annotations.forEach { $0.isReadOnly = !enabled }
        }
        self.pdfView.clearSelection()
    }

    /// Turns the current text selection into markup annotations — one per line, so a
    /// selection spanning several lines does not produce a single block covering the
    /// whitespace between them.
    @MainActor
    func annotateSelection() {
        guard self.annotationMode, let selection = self.pdfView.currentSelection else { return }

        var addedCount = 0
        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 1, bounds.height > 1 else { continue }
                let annotation = PDFAnnotation(bounds: bounds,
                                               forType: self.annotationType.subtype,
                                               withProperties: nil)
                annotation.color = UIColor(self.annotationColor)
                page.addAnnotation(annotation)
                self.addedAnnotations.append((page: page, annotation: annotation))
                addedCount += 1
            }
        }

        guard addedCount > 0 else { return }
        self.hasUnsavedAnnotations = true
        self.pdfView.clearSelection()
        self.pdfView.setNeedsDisplay()
        self.analyticsManager.track(event: .annotationAdded(type: self.annotationType))
    }

    /// Undoes the last markup applied in this session.
    ///
    /// Deliberately an undo rather than tap-to-delete: a delete gesture on `PDFView`
    /// competes with its own text selection, and a markup tool whose taps sometimes
    /// erase instead of select is worse than one that simply steps back. Annotations
    /// already saved in previous sessions are not touched.
    @MainActor
    func undoLastAnnotation() {
        guard self.annotationMode, let last = self.addedAnnotations.popLast() else { return }
        last.page.removeAnnotation(last.annotation)
        self.hasUnsavedAnnotations = !self.addedAnnotations.isEmpty
        self.pdfView.setNeedsDisplay()
    }

    var canUndoAnnotation: Bool { !self.addedAnnotations.isEmpty }

    // MARK: - Persistence

    /// Closing with unsaved markup asks first; without any, it just closes.
    @MainActor
    func requestClose(onClose: @escaping () -> Void) {
        if self.hasUnsavedAnnotations {
            self.unsavedChangesAlertShow = true
        } else {
            onClose()
        }
    }

    @MainActor
    @discardableResult
    func save() -> Bool {
        guard let document = self.pdfView.document,
              let data = document.dataRepresentation(),
              let savedDocument = PDFDocument(data: data) else {
            self.saveErrorShow = true
            return false
        }
        // Keeps the Core Data storeId: annotating updates the document in place, unlike
        // redaction, which must always produce a new file.
        var updatedPdf = self.pdf
        updatedPdf.updateDocument(savedDocument)
        do {
            let savedPdf = try self.repository.savePdf(pdf: updatedPdf)
            self.pdf = savedPdf
            self.hasUnsavedAnnotations = false
            // Once persisted these are part of the document, not pending edits.
            self.addedAnnotations = []
            self.analyticsManager.track(event: .annotationsSaved)
            self.onSaved?(savedPdf)
            return true
        } catch {
            debugPrint(for: self, message: "Failed to save annotations. Error: \(error)")
            self.saveErrorShow = true
            return false
        }
    }

    @MainActor
    func discardChanges() {
        self.hasUnsavedAnnotations = false
    }
    
    @objc private func handlePageChange(notification: Notification) {
        guard let currentPageindex = self.pdfView.currentPageIndex, notification.object as? PDFView == self.pdfView else {
            assertionFailure("Missing expected page index")
            return
        }
        self.pageIndex = currentPageindex
    }
}

fileprivate extension NSAttributedString {
    
    func getPdfBodyText(fontScale: CGFloat) -> AttributedString? {
        
        let trimmedAttributedString = self.attributedStringByTrimmingCharacterSet(charSet: .whitespacesAndNewlines)
        
        guard trimmedAttributedString.length > 0 else {
            return nil
        }
        
        var attributedString = AttributedString(trimmedAttributedString)
        attributedString.foregroundColor = ColorPalette.primaryText
        for run in attributedString.runs {
            let fontSize: CGFloat? = run.uiKit.font?.fontDescriptor
                .fontAttributes[UIFontDescriptor.AttributeName.size] as? CGFloat
            let scaledFontSize = (fontSize ?? 16.0) * fontScale
            attributedString[run.range].font = FontPalette.fontMedium(withSize: scaledFontSize)
        }
        return attributedString
    }
}
