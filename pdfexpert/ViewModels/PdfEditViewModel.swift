//
//  PdfEditViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import Factory
import SwiftUI
import UIKit
import PhotosUI
import PDFKit

extension Container {
    var pdfEditViewModel: ParameterFactory<PdfEditViewModel.InputParameter, PdfEditViewModel> {
        self { PdfEditViewModel(inputParameter: $0) }
    }
}

enum PdfEditStartAction {
    case openFillWidget
    case openFillForm
    case openSignature
    case openOcr
    case openRotate
    case openPageNumbers
    case openWatermark
    case openRemoveBlankPages
    case openFlatten
    case openInvertColors
}

/// One entry per page of the open document: the small image the strip and the
/// rail show, and an identity of its own.
///
/// The identity is what makes the full-size images cacheable. Pages get moved,
/// copied and deleted, so an index is not a name — the drag and drop even used
/// to find a page by comparing `UIImage`s.
struct EditorPage: Identifiable, Equatable {
    let id: UUID = UUID()
    var thumbnail: UIImage?
}

/// The editor's internal vocabulary for "run this, once the panel has finished
/// closing". The vocabulary the rest of the app speaks is `EditorTool`, which
/// `run(_:)` translates from; what is left here is only the tools that answer
/// with an alert or a cover rather than a screen — everything that pushes goes
/// straight through `push(_:)`.
private enum EditAction: CaseIterable {
    case password
    case ocr
    case removeBlankPages
    case flatten
    case invertColors
    case redact
}

class PdfEditViewModel: ObservableObject, SignedContainerImporting {
    
    struct InputParameter {
        let pdf: Pdf
        let startAction: PdfEditStartAction?
        let shouldShowCloseWarning: Binding<Bool>
    }
    
    @Published private(set)var pdf: Pdf
    @Published var pdfCurrentPageIndex: Int = 0 {
        didSet { self.refreshVisiblePageImages() }
    }
    /// One entry per page of the document, in order. Only the small images live
    /// here; the full-size ones are drawn on demand (see `loadedPageImages`).
    @Published private(set) var pages: [EditorPage] = [] {
        didSet { self.refreshVisiblePageImages() }
    }
    /// The full-size images currently in memory, keyed by page.
    ///
    /// The editor used to hold one per page for the whole session — about 2 MB
    /// each, so a fifty-page scan sat on ~100 MB of pictures of pages nobody was
    /// looking at. The pager shows one page at a time, so that is what is kept:
    /// the page on screen and its two neighbours.
    @Published private(set) var loadedPageImages: [EditorPage.ID: UIImage] = [:]
    /// The render in flight for a page, if there is one. A token rather than a
    /// flag, for two reasons: swiping back and forth over a page must not start a
    /// second render of it, and a page edited mid-render is being drawn as it
    /// *was* — that result has to be thrown away rather than land on top of the
    /// edit.
    private var pageImageRenders: [EditorPage.ID: UUID] = [:]
    /// How many pages either side of the one on screen are kept drawn. One: the
    /// pager can be swiped both ways, and a page drawn only once it is reached
    /// arrives visibly late.
    private static let pageImageWindow: Int = 1
    /// True while the pages are still being drawn. They arrive one at a time
    /// from a background queue (see `refreshPages`), so for a moment the editor
    /// knows how many pages the document has but not yet what they look like.
    @Published private(set) var isPreparingPages: Bool = false
    /// Bumped on every rebuild, so pages drawn for a document the editor has
    /// moved on from are dropped rather than appended to the new one.
    private var renderGeneration: Int = 0
    /// An edit that arrived before the pages did, waiting for them. Only one is
    /// ever queued: it comes from the start action, which runs once.
    private var pendingPageAction: (() -> Void)?

    /// How many pages the document has, which is known immediately — unlike the
    /// images of them.
    var pageCount: Int { self.pdf.pdfDocument.pageCount }

    /// Whether the page operations can run. They all edit the document and the
    /// page list in step, so they have to wait until there is one entry per page
    /// to edit.
    var canEditPages: Bool { !self.isPreparingPages }
    @Published var pdfSaveError: PdfEditSaveError? = nil
    @Published var filePickerShow: Bool = false
    @Published var imagePickerShow: Bool = false
    @Published var cameraPermissionDeniedShow: Bool = false
    @Published var missingWidgetWarningShow: Bool = false
    
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet {
            if let imageSelection {
                let progress = self.loadTransferable(from: imageSelection)
                self.asyncImageLoading = AsyncOperation(status: .loading(progress))
            } else {
                self.asyncImageLoading = AsyncOperation(status: .empty)
            }
        }
    }
    
    @Published var asyncImageLoading: AsyncOperation<(), SharedUnderlyingError> = AsyncOperation(status: .empty)
    @Published var asyncPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let pdf = self.asyncPdf.data  {
                self.appendPdfToPdf(pdf: pdf)
                self.asyncPdf = AsyncOperation(status: .empty)
            }
        }
    }

    // OCR replaces the current document with its searchable version (unlike
    // asyncPdf, which appends), so it has its own async channel.
    @Published var asyncOcr: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let pdf = self.asyncOcr.data {
                self.updatePdf(pdf: pdf)
                self.asyncOcr = AsyncOperation(status: .empty)
                self.analyticsManager.track(event: .ocrCompleted)
            }
        }
    }
    
    // Document-hygiene tools (remove blank pages / flatten / invert colors) replace the
    // whole document, like OCR — hence their own channel rather than asyncPdf, which appends.
    @Published var asyncCleanup: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let pdf = self.asyncCleanup.data {
                self.updatePdf(pdf: pdf)
                self.asyncCleanup = AsyncOperation(status: .empty)
            }
        }
    }

    /// The editor's plain "here is what that did" alert, shared by the tools that
    /// finish in place — hygiene and OCR. Both titles and message are set right
    /// before it is shown, because a tool that found nothing to do has to be able
    /// to say so under "Info" rather than under "Done".
    @Published var toolOutcomeAlertShow: Bool = false
    private(set) var toolOutcomeAlertTitle: String = ""
    private(set) var toolOutcomeAlertMessage: String = ""

    @Published var saveSuccessfulAlertShow: Bool = false
    
    @Published var pdfFilename: String {
        didSet {
            self.onPdfChanged()
        }
    }

    /// A name the document proposes for itself, from its metadata or its own first
    /// page (see `PdfTitleUtility`). Offered, never applied: it sits in a bar the
    /// user can accept or dismiss, because a name chosen for someone is a name they
    /// have to go and undo.
    @Published private(set) var suggestedFilename: String? = nil
    /// Dismissed once, gone for this editing session — re-offering it after every
    /// page added would be nagging.
    private var filenameSuggestionDismissed: Bool = false
    /// The modals the editor still owns: the ones that are direct manipulation
    /// of the page, or a system picker. Everything that merely asks a question
    /// is pushed onto `path` instead.
    enum ActiveSheet: Identifiable {
        case camera, scanner, signature, fillForm, fillWidget
        var id: Self { self }
    }

    @Published var activeSheet: ActiveSheet?
    /// The editor's own navigation stack, driven by `EditorRoute`.
    @Published var path: [EditorRoute] = []
    /// The panel behind the wrench, listing everything that acts on the whole
    /// document.
    @Published var toolPanelShow: Bool = false

    @Published var passwordTextFieldShow: Bool = false
    @Published var removePasswordAlertShow: Bool = false
    @Published var splitSuccessAlertShow: Bool = false
    @Published var extractSuccessAlertShow: Bool = false

    @Injected(\.repository) private var repository
    @Injected(\.mainCoordinator) private var mainCoordinator
    @Injected(\.pdfCoordinator) private var pdfCoordinator
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.pdfShareCoordinator) var pdfShareCoordinator
    @Injected(\.pdfSplitViewModel) var pdfSplitViewModel
    @Injected(\.pdfExtractViewModel) var pdfExtractViewModel
    @Injected(\.pdfExportViewModel) var pdfExportViewModel
    @Injected(\.pdfPermissionsViewModel) var pdfPermissionsViewModel
    @Injected(\.pdfRedactViewModel) var pdfRedactViewModel
    @Injected(\.pdfCompressViewModel) var pdfCompressViewModel

    lazy var pdfUnlockViewModel: PdfUnlockViewModel = {
        Container.shared.pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfSingleOutput: self.asyncSubject(\.asyncPdf)))
    }()

    // Office / iWork documents added as pages are converted on-device, with an optional
    // online fallback (see OfficeImportCoordinator). Replaces the former PSPDFKit call.
    /// Set when a signed container has been opened: drives the sheet that shows who
    /// signed it, before the document inside is imported.
    @Published var signedDocument: SignedDocumentPresentation? = nil

    lazy var officeImportCoordinator: OfficeImportCoordinator = {
        Container.shared.officeImportCoordinator(OfficeImportCoordinator.Params(asyncPdf: self.asyncSubject(\.asyncPdf)))
    }()
    
    // This boolean is set to true every time a change is applied to the original pdf.
    // TODO: Find a more robust solution
    var shouldShowCloseWarning: Binding<Bool>
    var urlToFileToConvert: URL?
    var imageToConvert: UIImage?
    /// Pages waiting to be appended, handed over by the scanner.
    var scannedPages: [ScannedPage]?
    
    var currentAnalyticsPdfInputType: AnalyticsPdfInputType? = nil
    var currentAnalyticsInputFileExtension: String? = nil
    var startAction: PdfEditStartAction? = nil
    #if DEBUG
    private var debugSheetOpened: Bool = false
    #endif
    
    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        self.pdfFilename = inputParameter.pdf.filename
        self.startAction = inputParameter.startAction
        self.shouldShowCloseWarning = inputParameter.shouldShowCloseWarning
        self.refreshPages()
    }
    
    @MainActor
    func onAppear() {
        // Defer to the next runloop so the edit view is fully presented before the
        // start-action sheet is driven (replaces a fixed Task.sleep delay).
        DispatchQueue.main.async {
            if let startAction = self.startAction {
                switch startAction {
                case .openFillWidget:
                    if PDFUtility.hasPdfWidget(pdf: self.pdf) {
                        self.activeSheet = .fillWidget
                    } else {
                        self.missingWidgetWarningShow = true
                    }
                case .openFillForm:
                    self.activeSheet = .fillForm
                case .openSignature:
                    self.activeSheet = .signature
                case .openOcr:
                    self.startOcr()
                case .openRotate:
                    // The one start action that edits the document rather than
                    // opening something, so it waits for the pages (see
                    // `whenPagesAreReady`) instead of being dropped by the guard
                    // in `rotateAllPages`.
                    self.whenPagesAreReady { [weak self] in self?.run(.rotateAllPages) }
                case .openPageNumbers:
                    self.startPageNumbers()
                case .openWatermark:
                    self.startWatermark()
                case .openRemoveBlankPages:
                    self.runCleanup(.removeBlankPages)
                case .openFlatten:
                    self.runCleanup(.flatten)
                case .openInvertColors:
                    self.runCleanup(.invertColors)
                }
            }
            self.startAction = nil
            self.refreshFilenameSuggestion()
            #if DEBUG
            self.openDebugSheetIfNeeded()
            #endif
        }
    }

    // MARK: - Proposed name

    /// Recomputed whenever the document changes, since the text it is read from can
    /// arrive later than the document does — an OCR run is the usual case, and a
    /// scan has nothing to read before it.
    func refreshFilenameSuggestion() {
        guard !self.filenameSuggestionDismissed,
              Pdf.isGeneratedFilename(self.pdfFilename) else {
            self.suggestedFilename = nil
            return
        }
        let suggestion = PdfTitleUtility.suggestedName(for: self.pdf.pdfDocument)
        self.suggestedFilename = suggestion == self.pdfFilename ? nil : suggestion
    }

    @MainActor
    func useSuggestedFilename() {
        guard let suggestion = self.suggestedFilename else { return }
        // Goes through the same published property a manual rename does, so the
        // close warning and the rename event are handled in one place.
        self.pdfFilename = suggestion
        self.suggestedFilename = nil
    }

    @MainActor
    func dismissFilenameSuggestion() {
        self.filenameSuggestionDismissed = true
        self.suggestedFilename = nil
    }

    #if DEBUG
    /// Opens one of the editor's own tool screens, which are otherwise behind a tap
    /// in the tool panel that a simulator cannot deliver:
    ///   xcrun simctl spawn booted defaults write <bundle-id> debugEditorSheet -string watermark
    /// Values: `pageNumbers`, `watermark`, `metadata`, `tools`, `reorder`, `split`,
    /// `extract`, `export`, `compress`, `permissions`, `addText`, `signature`. Page
    /// numbers, watermark and permissions are premium, so `debugPremium -bool YES` is
    /// needed too; split and extract need a document of more than one page.
    @MainActor
    private func openDebugSheetIfNeeded() {
        // The editor's `onAppear` runs again every time a pushed tool is popped,
        // so without this the tool reopens itself and there is no way back.
        guard !self.debugSheetOpened else { return }
        self.debugSheetOpened = true
        switch UserDefaults.standard.string(forKey: "debugEditorSheet") {
        case "pageNumbers": self.startPageNumbers()
        case "watermark": self.startWatermark()
        case "metadata": self.push(.metadata)
        case "tools": self.toolPanelShow = true
        case "reorder": self.push(.reorderPages)
        case "split": self.startSplit()
        case "extract": self.startExtract()
        case "export": self.startExport()
        case "compress": self.startCompress()
        case "permissions": self.startPermissions()
        case "addText": self.showFillForm()
        case "signature": self.showAddSignature()
        default: break
        }
    }
    #endif

    func deleteCurrentPage() {
        // Not an inconsistency while the pages are still arriving — just too
        // early. The bar that calls this is disabled until they are all in.
        guard self.canEditPages else { return }
        guard self.pages.count == self.pdf.pdfDocument.pageCount else {
            assertionFailure("Inconsistency error: page count doesn't match pdf pages count")
            return
        }
        let maxIndex = self.pdf.pdfDocument.pageCount

        guard self.pdfCurrentPageIndex >= 0, self.pdfCurrentPageIndex < maxIndex else {
            debugPrint(for: self, message: "Out of bound index!")
            return
        }
        self.pdf.pdfDocument.removePage(at: self.pdfCurrentPageIndex)
        // The drawn image goes with it: nothing else refers to that page id.
        self.pages.remove(at: self.pdfCurrentPageIndex)

        let newMaxIndex = self.pdf.pdfDocument.pageCount
        
        if self.pdfCurrentPageIndex >= newMaxIndex {
            self.pdfCurrentPageIndex = (newMaxIndex > 0) ? newMaxIndex - 1 : 0
        }
        
        self.shouldShowCloseWarning.wrappedValue = true

        self.analyticsManager.track(event: .pageRemoved)
    }

    /// Deletes a page by index, from the reorder screen where the page being
    /// removed is not necessarily the one on display.
    @MainActor
    func deletePage(at index: Int) {
        guard index >= 0, index < self.pdf.pdfDocument.pageCount else { return }
        let previousIndex = self.pdfCurrentPageIndex
        self.pdfCurrentPageIndex = index
        self.deleteCurrentPage()
        // Keep looking at what the user was looking at, unless that page is the
        // one that just went.
        if previousIndex != index {
            self.pdfCurrentPageIndex = min(previousIndex > index ? previousIndex - 1 : previousIndex,
                                           max(self.pdf.pdfDocument.pageCount - 1, 0))
        }
    }

    /// Copies the current page and puts the copy straight after it — the one
    /// page operation the editor was missing, and the usual way of filling in
    /// the same form twice.
    @MainActor
    func duplicateCurrentPage() {
        guard self.canEditPages else { return }
        // Not `page.copy()`: that brings the page's structure — annotation
        // rectangles included — and leaves the resources behind, so a duplicated
        // page arrived without the signature on it while the empty box was still
        // there to be tapped and dragged. Same PDFKit behaviour that made every
        // full-size page image blank; same answer, through the page's own bytes.
        guard let page = self.pdf.pdfDocument.page(at: self.pdfCurrentPageIndex),
              let copy = PDFUtility.detachedPage(from: page) else {
            return
        }
        let destination = self.pdfCurrentPageIndex + 1
        self.pdf.pdfDocument.insert(copy, at: destination)

        let thumbnail = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdf.pdfDocument,
                                                        size: K.Misc.ThumbnailEditSize,
                                                        forPageIndex: destination)
        self.pages.insert(EditorPage(thumbnail: thumbnail), at: destination)

        self.pdfCurrentPageIndex = destination
        self.shouldShowCloseWarning.wrappedValue = true
        self.analyticsManager.track(event: .pageDuplicated)
    }

    /// `onMove` semantics, for the reorder screen: SwiftUI hands over a set of
    /// source rows and the row they land before, which is not the pairwise swap
    /// `handlePageReordering` performs.
    @MainActor
    func movePages(from source: IndexSet, to destination: Int) {
        guard self.canEditPages, let from = source.first else { return }
        // A move to a later position counts the moving page itself, so the
        // landing index is one past where it ends up.
        let to = destination > from ? destination - 1 : destination
        guard from != to, to >= 0, to < self.pdf.pdfDocument.pageCount else { return }
        guard let page = self.pdf.pdfDocument.page(at: from) else { return }

        self.pdf.pdfDocument.removePage(at: from)
        self.pdf.pdfDocument.insert(page, at: to)
        // The entries move with their identity, so a page that has already been
        // drawn keeps its image instead of being drawn again in its new place.
        self.pages.move(fromOffsets: source, toOffset: destination)

        if self.pdfCurrentPageIndex == from {
            self.pdfCurrentPageIndex = to
        }
        self.shouldShowCloseWarning.wrappedValue = true
    }

    /// Rotates only the currently displayed page. Regenerates just that page's image
    /// and thumbnail (the full `refreshPages()` redraws every page).
    @MainActor
    func rotateCurrentPage(clockwise: Bool) {
        guard self.canEditPages,
              let page = self.pdf.pdfDocument.page(at: self.pdfCurrentPageIndex) else {
            return
        }
        PDFUtility.rotatePage(page, clockwise: clockwise)
        self.regenerateThumbnailEntries(at: self.pdfCurrentPageIndex)
        self.shouldShowCloseWarning.wrappedValue = true
        self.analyticsManager.track(event: .pageRotated(rotationType: .single))
    }

    /// Rotates every page in the document, then does the full images+thumbnails refresh
    /// (a per-page regeneration wouldn't be any cheaper here). Reached from the tool
    /// panel and from the Shortcuts "Rotate PDF" action; the bar under the page turns
    /// the page in front of the user, this turns the document.
    @MainActor
    func rotateAllPages(clockwise: Bool) {
        guard self.canEditPages else { return }
        for index in 0..<self.pdf.pdfDocument.pageCount {
            if let page = self.pdf.pdfDocument.page(at: index) {
                PDFUtility.rotatePage(page, clockwise: clockwise)
            }
        }
        self.refreshPages()
        self.shouldShowCloseWarning.wrappedValue = true
        self.analyticsManager.track(event: .pageRotated(rotationType: .all))
    }

    // MARK: - The pages on screen

    /// The full-size image of a page, if it has been drawn yet. The pager falls
    /// back to the thumbnail meanwhile: blurry for a moment reads as loading,
    /// blank reads as broken.
    func pageImage(at index: Int) -> UIImage? {
        guard index >= 0, index < self.pages.count else { return nil }
        return self.loadedPageImages[self.pages[index].id]
    }

    func pageThumbnail(at index: Int) -> UIImage? {
        guard index >= 0, index < self.pages.count else { return nil }
        return self.pages[index].thumbnail
    }

    /// Keeps the pages around the one on screen drawn and drops the rest. Runs on
    /// the main thread, from the two `didSet`s above: whenever the page being
    /// looked at changes, and whenever the list of pages does.
    private func refreshVisiblePageImages() {
        guard !self.pages.isEmpty else {
            self.loadedPageImages = [:]
            return
        }
        let lower = max(self.pdfCurrentPageIndex - Self.pageImageWindow, 0)
        let upper = min(self.pdfCurrentPageIndex + Self.pageImageWindow, self.pages.count - 1)
        guard lower <= upper else { return }

        let wanted = Set(self.pages[lower...upper].map(\.id))
        if self.loadedPageImages.contains(where: { !wanted.contains($0.key) }) {
            self.loadedPageImages = self.loadedPageImages.filter { wanted.contains($0.key) }
        }
        for index in lower...upper where self.loadedPageImages[self.pages[index].id] == nil {
            self.drawPageImage(at: index)
        }
    }

    /// Draws one page at full size, off the main thread.
    ///
    /// The page is detached first, here on the main thread, because the document
    /// it belongs to can be edited while the drawing is still going — rotating or
    /// deleting a page out from under a render is a crash waiting to happen.
    ///
    /// This used to be `page.copy()`, and that is exactly what "Image to PDF
    /// shows a white page" was: PDFKit copies the page's structure without the
    /// resources its content refers to, so the copy draws blank. It goes through
    /// the page's own bytes now — see `PDFUtility.detachedPage(from:)`, which has
    /// the measurements.
    private func drawPageImage(at index: Int) {
        guard index >= 0, index < self.pages.count,
              let page = self.pdf.pdfDocument.page(at: index),
              let copy = PDFUtility.detachedPage(from: page) else { return }
        let id = self.pages[index].id
        guard self.pageImageRenders[id] == nil else { return }
        let token = UUID()
        self.pageImageRenders[id] = token

        DispatchQueue.global(qos: .userInitiated).async {
            let image = PDFUtility.generatePageImage(copy)
            DispatchQueue.main.async {
                // Superseded: the page was edited while this was being drawn, and
                // what came back is a picture of the page before the edit.
                guard self.pageImageRenders[id] == token else { return }
                self.pageImageRenders[id] = nil
                // Or it was scrolled away from, or deleted — keeping the image
                // would put back exactly the memory this is here to save.
                guard self.isWithinPageImageWindow(id) else { return }
                self.loadedPageImages[id] = image
            }
        }
    }

    /// Whether a page is still one of the ones being looked at.
    private func isWithinPageImageWindow(_ id: EditorPage.ID) -> Bool {
        guard let index = self.pages.firstIndex(where: { $0.id == id }) else { return false }
        return abs(index - self.pdfCurrentPageIndex) <= Self.pageImageWindow
    }

    /// Runs an edit once every page has been drawn, or straight away if they are
    /// already in. The page operations mutate the document that the render pass
    /// is still reading on its own queue, which is why they all guard on
    /// `canEditPages` — but a tool asked for before the editor even appeared (a
    /// Shortcuts action) deserves to run late rather than not at all.
    @MainActor
    private func whenPagesAreReady(_ action: @escaping () -> Void) {
        guard self.isPreparingPages else {
            action()
            return
        }
        self.pendingPageAction = action
    }

    /// The one place the drawing is declared finished, so anything waiting on the
    /// pages runs here and nowhere else.
    private func finishPreparingPages() {
        self.isPreparingPages = false
        guard let action = self.pendingPageAction else { return }
        self.pendingPageAction = nil
        action()
    }

    /// Redraws a single page after an edit to it. The thumbnail is small enough to
    /// draw here and now; the full-size image is dropped instead, and drawn again
    /// by the window if the page is one of the ones being looked at.
    private func regenerateThumbnailEntries(at index: Int) {
        guard index >= 0, index < self.pdf.pdfDocument.pageCount, index < self.pages.count else { return }
        // Both the image and any render still on its way: they are of the page
        // before this edit.
        self.loadedPageImages[self.pages[index].id] = nil
        self.pageImageRenders[self.pages[index].id] = nil
        self.pages[index].thumbnail = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdf.pdfDocument,
                                                                      size: K.Misc.ThumbnailEditSize,
                                                                      forPageIndex: index)
    }

    func openFilePicker() {
        self.filePickerShow = true
        self.currentAnalyticsPdfInputType = .file
    }
    
    func openCamera() {
        self.activeSheet = .camera
        self.currentAnalyticsPdfInputType = .camera
    }
    
    func openGallery() {
        self.imagePickerShow = true
        self.currentAnalyticsPdfInputType = .gallery
    }
    
    func openScanner() {
        self.currentAnalyticsPdfInputType = .scan
        self.showScanner()
    }
    
    func save() {
        do {
            try self.internalSave()
            self.saveSuccessfulAlertShow = true
        } catch let error as PdfEditSaveError  {
            debugPrint(for: self, message: "Pdf save failed with error: \(error)")
            self.pdfSaveError = error
        } catch {
            self.pdfSaveError = .unknown
        }
    }
    
    func share() {
        do {
            try self.internalSave()
            self.internalShare()
        } catch let error as PdfEditSaveError  {
            debugPrint(for: self, message: "Pdf save failed with error: \(error)")
            self.pdfSaveError = error
        } catch {
            self.pdfSaveError = .unknown
        }
    }
    
    func goToArchive() {
        self.mainCoordinator.closePdfEditFlow()
        self.mainCoordinator.goToArchive()
    }
    
    /// The annotation the user touched on the page, handed to the tool that owns
    /// it so it opens straight into editing that element rather than making a new
    /// one. Consumed once — see `consumeAnnotationToEdit()`.
    private var annotationToEdit: PDFAnnotation? = nil

    func consumeAnnotationToEdit() -> PDFAnnotation? {
        defer { self.annotationToEdit = nil }
        return self.annotationToEdit
    }

    /// A tap on the page. If it landed on a signature or on a piece of text, the
    /// matching tool opens with that element already selected; otherwise nothing
    /// happens, because a tap on the page itself has no other meaning here.
    ///
    /// This is what "I want to fix the thing I just placed" needs: the elements
    /// are annotations in the document, and the two tools can already edit one —
    /// what was missing was a way to say *which*, without reopening a tool and
    /// hunting for it.
    @MainActor
    func tapOnPage(at point: CGPoint, viewSize: CGSize) {
        guard let page = self.pdf.pdfDocument.page(at: self.pdfCurrentPageIndex),
              let pointInPage = Self.pointInPage(point, viewSize: viewSize, page: page) else {
            return
        }
        let annotations = page.annotations
        if let signature = annotations.first(where: { $0.isSignatureAnnotation && $0.bounds.contains(pointInPage) }) {
            self.annotationToEdit = signature
            self.activeSheet = .signature
        } else if let text = annotations.first(where: { $0.isTextAnnotation && $0.bounds.contains(pointInPage) }) {
            self.annotationToEdit = text
            self.activeSheet = .fillForm
        }
    }

    /// Where a tap on the pager lands in the page's own coordinates.
    ///
    /// The pager draws an image, not a `PDFView`, so there is no `convert(_:to:)`
    /// to lean on: the image is drawn aspect-fit, which letterboxes it, and PDF
    /// space has its origin at the bottom left while a tap arrives with y going
    /// down. Returns nil for a tap in the letterbox — that is the background, not
    /// the page.
    static func pointInPage(_ point: CGPoint, viewSize: CGSize, page: PDFPage) -> CGPoint? {
        let mediaBox = page.bounds(for: .mediaBox)
        // A quarter-turned page is drawn with its sides swapped.
        let drawnSize = (page.rotation % 180 != 0)
            ? CGSize(width: mediaBox.height, height: mediaBox.width)
            : mediaBox.size
        let fitted = ScanPreviewGeometry.fittedRect(imageSize: drawnSize, in: viewSize)
        guard fitted.width > 0, fitted.height > 0, fitted.contains(point) else { return nil }

        let across = (point.x - fitted.minX) / fitted.width
        let down = (point.y - fitted.minY) / fitted.height
        return CGPoint(x: mediaBox.minX + across * mediaBox.width,
                       y: mediaBox.maxY - down * mediaBox.height)
    }

    func showAddSignature() {
        self.activeSheet = .signature
    }

    func showFillForm() {
        self.activeSheet = .fillForm
    }

    func showFillWidget() {
        if PDFUtility.hasPdfWidget(pdf: self.pdf) {
            self.activeSheet = .fillWidget
        } else {
            self.missingWidgetWarningShow = true
        }
    }
    
    /// The single entry point for every tool, whichever bar or panel it was
    /// tapped in. What each one does is decided here; *how* it appears is
    /// `EditorTool.presentation`.
    @MainActor
    func run(_ tool: EditorTool) {
        switch tool {
        case .rotateLeft: self.rotateCurrentPage(clockwise: false)
        case .rotateRight: self.rotateCurrentPage(clockwise: true)
        case .rotateAllPages: self.rotateAllPages(clockwise: true)
        case .duplicatePage: self.duplicateCurrentPage()
        case .deletePage: break // the view asks first
        case .addPage: break    // the view asks where from
        case .reorderPages: self.push(.reorderPages)
        case .signature: self.showAddSignature()
        case .addText: self.showFillForm()
        case .fillForm: self.showFillWidget()
        case .split: self.startSplit()
        case .extractPages: self.startExtract()
        case .removeBlankPages: self.handleEditAction(.removeBlankPages)
        case .ocr: self.handleEditAction(.ocr)
        case .pageNumbers: self.startPageNumbers()
        case .watermark: self.startWatermark()
        case .invertColors: self.handleEditAction(.invertColors)
        case .flatten: self.handleEditAction(.flatten)
        case .password: self.handleEditAction(.password)
        case .permissions: self.startPermissions()
        case .redact: self.handleEditAction(.redact)
        case .compress: self.startCompress()
        case .export: self.startExport()
        case .metadata: self.push(.metadata)
        case .share: self.share()
        }
    }

    @MainActor
    func push(_ route: EditorRoute) {
        self.path.append(route)
    }

    @MainActor
    private func handleEditAction(_ action: EditAction) {
        // Defer to the next runloop so the tool panel finishes dismissing before
        // the follow-up modal/alert is presented (replaces a fixed Task.sleep).
        DispatchQueue.main.async {
            switch action {
            case .password:
                if self.pdf.password != nil {
                    self.removePasswordAlertShow = true
                } else {
                    self.passwordTextFieldShow = true
                }
            case .ocr:
                self.startOcr()
            case .removeBlankPages:
                self.runCleanup(.removeBlankPages)
            case .flatten:
                self.runCleanup(.flatten)
            case .invertColors:
                self.runCleanup(.invertColors)
            case .redact:
                self.pdfRedactViewModel.run(pdf: self.pdf, onCompleted: nil)
            }
        }
    }

    // MARK: - The pushed flows
    //
    // Each of these hands the open document to the tool's own view model and
    // pushes its form. `prepare` is the half of the flow's entry point that
    // stops short of presenting: it is synchronous and says whether there is
    // anything to show, so a document that cannot be split — one page — reports
    // that instead of getting a screen with nothing on it. From there the flow
    // runs as it always did; the form comes back off the stack when the flow
    // lowers its own flag (see `popWhenFormCloses`).

    @MainActor
    func startSplit() {
        let opened = self.pdfSplitViewModel.prepare(pdf: self.pdf, onSplitCompleted: { [weak self] in
            self?.splitSuccessAlertShow = true
        })
        if opened { self.push(.split) }
    }

    @MainActor
    func startExtract() {
        let opened = self.pdfExtractViewModel.prepare(pdf: self.pdf, onExtractCompleted: { [weak self] in
            self?.extractSuccessAlertShow = true
        })
        if opened { self.push(.extractPages) }
    }

    /// Free to open: export is premium per *format*, and that gate lives in the
    /// flow, after the choice has been made.
    @MainActor
    func startExport() {
        if self.pdfExportViewModel.prepare(pdf: self.pdf) { self.push(.export) }
    }

    /// The Compress tool, the same one the catalog offers: it reports what the
    /// compression actually costs instead of storing a preference whose effect
    /// the archive never shows.
    @MainActor
    func startCompress() {
        if self.pdfCompressViewModel.prepare(pdf: self.pdf, onCompleted: nil) { self.push(.compress) }
    }

    @MainActor
    func startPermissions() {
        if self.pdfPermissionsViewModel.prepare(pdf: self.pdf, onCompleted: nil) {
            self.push(.permissions)
        }
    }

    /// Applies edited metadata coming back from the metadata editor. Metadata never
    /// affects rendering, so this deliberately avoids the heavy
    /// `refreshPages()` full rebuild that `updatePdf(pdf:)`
    /// does; it only swaps in the updated `Pdf` and marks the document dirty.
    func applyMetadata(pdf: Pdf) {
        self.pdf = pdf
        self.shouldShowCloseWarning.wrappedValue = true
    }

    /// Entry point for the OCR / searchable-PDF tool. Runs on device and stays in
    /// the document, so it is free like the rest of the editor: the paywall is met
    /// once, on the way out (see `PdfShareCoordinator`).
    @MainActor
    func startOcr() {
        self.performOcr()
    }

    @MainActor
    private func performOcr() {
        self.analyticsManager.track(event: .ocrStarted)
        OcrUtility.makeSearchable(pdf: self.pdf,
                                  asyncOperation: self.asyncSubject(\.asyncOcr),
                                  onCompleted: { [weak self] result in
            guard let self = self else { return }
            // A run that recognized nothing is not a failure, and used to be
            // indistinguishable from one: the document came back unchanged with
            // nothing said. Each of the three outcomes now has its own sentence.
            if result.didChangeDocument {
                self.toolOutcomeAlertTitle = String(localized: "Done")
                self.toolOutcomeAlertMessage = String(localized: "Pages made searchable: \(result.ocredPageCount)")
            } else if result.wasAlreadySearchable {
                self.toolOutcomeAlertTitle = String(localized: "Info")
                self.toolOutcomeAlertMessage = String(localized: "Your PDF is already searchable. You can search and select its text as it is.")
            } else if result.alreadySearchablePageCount > 0 {
                // Some pages carried text and the rest — a photo, a blank scan —
                // gave Vision nothing. Saying only "no text was recognized" hid
                // the part that was already searchable and read like a failure.
                self.toolOutcomeAlertTitle = String(localized: "Info")
                self.toolOutcomeAlertMessage = String(localized: "\(result.alreadySearchablePageCount) pages were already searchable. No text was recognized on the remaining \(result.unrecognizedPageCount).")
            } else {
                self.toolOutcomeAlertTitle = String(localized: "Info")
                self.toolOutcomeAlertMessage = String(localized: "No text was recognized in your PDF.")
            }
            self.toolOutcomeAlertShow = true
        })
    }

    /// Entry point for the document-hygiene tools. All three are free and on-device, so
    /// there is no gate: they run straight away and report their outcome in an alert.
    @MainActor
    func runCleanup(_ operation: PdfCleanupOperation) {
        PdfCleanupUtility.run(operation,
                              pdf: self.pdf,
                              asyncOperation: self.asyncSubject(\.asyncCleanup),
                              onCompleted: { [weak self] removedCount in
            guard let self = self else { return }
            switch operation {
            case .removeBlankPages:
                // Phrased as a count rather than "N blank pages were removed" so the
                // sentence stays correct for 1 as well, in every language.
                self.toolOutcomeAlertTitle = removedCount > 0
                    ? String(localized: "Done")
                    : String(localized: "Info")
                self.toolOutcomeAlertMessage = removedCount > 0
                    ? String(localized: "Blank pages removed: \(removedCount)")
                    : String(localized: "No blank pages were found in your PDF.")
                self.analyticsManager.track(event: .blankPagesRemoved(count: removedCount))
            case .flatten:
                self.toolOutcomeAlertTitle = String(localized: "Done")
                self.toolOutcomeAlertMessage = String(localized: "Your PDF has been flattened. Annotations and form fields are now part of the page.")
                self.analyticsManager.track(event: .pdfFlattened)
            case .invertColors:
                self.toolOutcomeAlertTitle = String(localized: "Done")
                self.toolOutcomeAlertMessage = String(localized: "Colors have been inverted.")
                self.analyticsManager.track(event: .colorsInverted)
            }
            self.toolOutcomeAlertShow = true
        })
    }

    @MainActor
    func startPageNumbers() {
        self.push(.pageNumbers)
    }

    @MainActor
    func startWatermark() {
        self.push(.watermark)
    }

    /// The watermark tool has filed its copy. Said here rather than on the tool's
    /// own screen, which is being popped at this moment — and worth saying at all
    /// because the document on screen is deliberately *not* the one that got the
    /// watermark: it cannot be taken off a page once drawn, so the clean original
    /// stays open and the stamped version becomes a document of its own.
    @MainActor
    func onWatermarkSaved() {
        self.toolOutcomeAlertTitle = String(localized: "Done")
        self.toolOutcomeAlertMessage = String(localized: "A watermarked copy has been saved to your archive. This document is unchanged.")
        self.toolOutcomeAlertShow = true
    }

    func setPassword(_ password: String) {
        self.internalSetPassword(password)
        debugPrint(for: self, message: "New password set")
        self.analyticsManager.track(event: .passwordAdded)
    }
    
    func removePassword() {
        self.internalSetPassword(nil)
        debugPrint(for: self, message: "Password removed")
        self.analyticsManager.track(event: .passwordRemoved)
    }
    
    @MainActor
    func convert() {
        if let urlToFileToConvert = self.urlToFileToConvert {
            self.urlToFileToConvert = nil
            self.convertFileByUrl(fileUrl: urlToFileToConvert)
        } else if let imageToConvert = self.imageToConvert {
            self.imageToConvert = nil
            self.appendUiImageToPdf(uiImage: imageToConvert)
        } else if let scannedPages = self.scannedPages {
            self.scannedPages = nil
            PdfScanUtility.convertScan(pages: scannedPages, asyncOperation: self.asyncSubject(\.asyncPdf))
        }
    }
    
    func updatePdf(pdf: Pdf) {
        // TODO: Update thumbnails only for changed pages
        self.pdf = pdf
        self.shouldShowCloseWarning.wrappedValue = true
        self.refreshPages()
        self.refreshFilenameSuggestion()
    }
    
    func handlePageReordering(fromIndex: Int, toIndex: Int) {
        guard self.canEditPages else { return }
        if fromIndex != toIndex {
            // exchangePage throws an exception if used after pages are added. Apparently it doesn't update its internal indices when adding pages,
            // which it relies upon to perform the swap. A manual workaround using removePage and insert methods seems to work fine, though.
//            self.pdf.pdfDocument.exchangePage(at: fromIndex, withPageAt: toIndex)
            if let toPage = self.pdf.pdfDocument.page(at: toIndex), let fromPage = self.pdf.pdfDocument.page(at: fromIndex) {
                self.pdf.pdfDocument.removePage(at: fromIndex)
                self.pdf.pdfDocument.insert(toPage, at: fromIndex)
                self.pdf.pdfDocument.removePage(at: toIndex)
                self.pdf.pdfDocument.insert(fromPage, at: toIndex)
                
                // A swap, like the document above — this used to be a `move`,
                // which agrees with a swap only for neighbouring pages. Drag a
                // thumbnail two places along in one go and the strip showed one
                // order while the document was saved in another.
                self.pages.swapAt(fromIndex, toIndex)
                if self.pdfCurrentPageIndex == fromIndex {
                    self.pdfCurrentPageIndex = toIndex
                } else if self.pdfCurrentPageIndex == toIndex {
                    self.pdfCurrentPageIndex = fromIndex
                }
                self.shouldShowCloseWarning.wrappedValue = true
            }
        }
    }
    
    private func internalSave() throws {
        guard self.pdf.pdfDocument.pageCount > 0 else {
            throw PdfEditSaveError.noPages
        }
        self.pdf = try self.repository.savePdf(pdf: self.pdf)
        self.shouldShowCloseWarning.wrappedValue = false
    }
    
    private func internalShare() {
        self.pdfShareCoordinator.share(pdf: self.pdf, onComplete: { [weak self] in
            self?.pdfCoordinator.startReview()
        })
    }

    private func onPdfChanged() {
        if self.pdf.filename != self.pdfFilename {
            self.pdf.updateFilename(self.pdfFilename)
            self.shouldShowCloseWarning.wrappedValue = true
            self.analyticsManager.track(event: .pdfRenamed)
        }
    }
    
    @MainActor
    func onSignedContainerFailure(_ error: PdfError) {
        self.asyncPdf = AsyncOperation(status: .error(error))
    }

    @MainActor
    func onSignedDocumentOpen(url: URL) {
        self.signedDocument = nil
        // Deferred so the sheet finishes dismissing before the editor is presented:
        // two presentations in the same runloop turn and the second is dropped.
        DispatchQueue.main.async { self.convertFileByUrl(fileUrl: url) }
    }

    @MainActor
    func convertFileByUrl(fileUrl: URL) {
        guard let fileUrl = self.unwrappingSignedContainer(fileUrl) else { return }
        let fileUtType = UTType(filenameExtension: fileUrl.pathExtension)
        if fileUtType?.conforms(to: .pdf) ?? false {
            self.importPdf(pdfUrl: fileUrl)
        } else if fileUtType?.conforms(to: .image) ?? false {
            self.convertFileImageByURL(fileImageUrl: fileUrl)
        } else {
            self.currentAnalyticsInputFileExtension = fileUrl.pathExtension
            self.officeImportCoordinator.convert(fileUrl: fileUrl)
        }
    }
    
    @MainActor
    func importPdf(pdfUrl: URL) {
        guard let pdf = Pdf(pdfUrl: pdfUrl) else {
            assertionFailure("Missing expected file for give url")
            return
        }
        
        self.currentAnalyticsInputFileExtension = pdfUrl.pathExtension
        self.pdfUnlockViewModel.unlockPdf(pdf: pdf)
    }
    
    @MainActor
    private func convertFileImageByURL(fileImageUrl: URL) {
        do {
            let imageData = try Data(contentsOf: fileImageUrl)
            guard let uiImage = UIImage(data: imageData) else {
                self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
                return
            }
            self.currentAnalyticsInputFileExtension = fileImageUrl.pathExtension
            self.appendUiImageToPdf(uiImage: uiImage)
        } catch {
            debugPrint(for: self, message: "Error retrieving file. Error: \(error)")
            self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
        }
    }
    
    private func loadTransferable(from imageSelection: PhotosPickerItem) -> Progress {
        return imageSelection.loadTransferable(type: PickedImage.self) { result in
            DispatchQueue.main.async {
                guard imageSelection == self.imageSelection else {
                    print("Failed to get the selected item.")
                    return
                }
                switch result {
                case .success(let image?):
                    self.asyncImageLoading = AsyncOperation(status: .data(()))
                    self.appendUiImageToPdf(uiImage: image.uiImage)
                case .success(nil):
                    self.asyncImageLoading = AsyncOperation(status: .empty)
                case .failure(let error):
                    let convertedError = SharedUnderlyingError.convertError(fromError: error)
                    self.asyncImageLoading = AsyncOperation(status: .error(convertedError))
                }
            }
        }
    }
    
    private func appendUiImageToPdf(uiImage: UIImage) {
        PDFUtility.appendImageToPdfDocument(pdfDocument: self.pdf.pdfDocument, uiImage: uiImage)
        // A page arriving mid-draw would be appended twice — once here, once by
        // the render still walking the document — so that render is abandoned
        // and the document is drawn again, new page included.
        guard !self.isPreparingPages else {
            self.shouldShowCloseWarning.wrappedValue = true
            self.trackPageAddedEvent()
            self.refreshPages()
            return
        }
        let thumbnail = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdf.pdfDocument,
                                                        size: K.Misc.ThumbnailEditSize,
                                                        forPageIndex: self.pdf.pdfDocument.pageCount - 1)
        self.pages.append(EditorPage(thumbnail: thumbnail))
        self.shouldShowCloseWarning.wrappedValue = true
        self.trackPageAddedEvent()
    }
    
    private func appendPdfToPdf(pdf: Pdf) {
        PDFUtility.appendPdfDocument(pdf.pdfDocument, toPdfDocument: self.pdf.pdfDocument)
        guard !self.isPreparingPages else {
            self.shouldShowCloseWarning.wrappedValue = true
            self.refreshFilenameSuggestion()
            self.trackPageAddedEvent()
            self.refreshPages()
            return
        }
        // Thumbnails of the pages that just arrived, drawn from the document they
        // came from — the same pages, and it has no edits queued against it.
        let thumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: pdf.pdfDocument, size: K.Misc.ThumbnailEditSize)
        self.pages.append(contentsOf: thumbnails.map { EditorPage(thumbnail: $0) })
        self.shouldShowCloseWarning.wrappedValue = true
        self.refreshFilenameSuggestion()
        self.trackPageAddedEvent()
    }
    
    private func showScanner() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            self.activeSheet = .scanner
        default:
            self.cameraPermissionDeniedShow = true
        }
    }
    
    private func internalSetPassword(_ password: String?) {
        if self.pdf.password != password {
            self.pdf.updatePassword(password)
            self.shouldShowCloseWarning.wrappedValue = true
            self.objectWillChange.send()
        }
    }
    
    /// Draws the strip — one small image per page — off the main thread, a page at
    /// a time. The full-size image of the page being looked at follows from
    /// `refreshVisiblePageImages`, which the growing list of pages triggers.
    ///
    /// This used to be two synchronous passes over the whole document inside
    /// `init`, and again after every tool. On a text document that is free; on a
    /// scan it is not, because the cost is decoding the photograph inside each
    /// page and it is paid whatever size comes out: measured at **0.9s per page
    /// on a Mac**, so a twenty-page scan froze the editor for eighteen seconds
    /// before it drew anything, and again after every edit. Nothing was broken —
    /// the app was busy — but a frozen editor and a broken one are the same thing
    /// to the person holding the phone.
    ///
    /// Now the pages arrive as they are drawn, and only the small image is drawn
    /// for all of them — which also halves what opening a scan costs, since the
    /// photograph inside each page was being decoded twice. `renderGeneration`
    /// drops the results of a render the document has moved on from.
    private func refreshPages() {
        self.renderGeneration += 1
        let generation = self.renderGeneration
        let document = self.pdf.pdfDocument
        let pageCount = document.pageCount

        self.pages = []
        self.pageImageRenders = [:]
        guard pageCount > 0 else {
            self.finishPreparingPages()
            return
        }
        self.isPreparingPages = true

        DispatchQueue.global(qos: .userInitiated).async {
            for index in 0..<pageCount {
                // The document is only mutated once every page is in, so this
                // walks a document nobody else is editing (see `canEditPages`).
                let thumbnail = PDFUtility.generatePdfThumbnail(pdfDocument: document,
                                                                size: K.Misc.ThumbnailEditSize,
                                                                forPageIndex: index)
                DispatchQueue.main.async {
                    guard generation == self.renderGeneration else { return }
                    // A page that would not draw still gets an entry: the page
                    // list has to agree with the document, or every edit after it
                    // acts on the wrong page.
                    self.pages.append(EditorPage(thumbnail: thumbnail))
                    if self.pages.count >= pageCount {
                        self.finishPreparingPages()
                    }
                }
            }
            DispatchQueue.main.async {
                guard generation == self.renderGeneration else { return }
                // Belt and braces: nothing should leave the editor preparing for
                // ever if a page silently fails to arrive.
                self.finishPreparingPages()
            }
        }
    }
    
    private func trackPageAddedEvent() {
        guard let currentAnalyticsPdfInputType = self.currentAnalyticsPdfInputType else {
            assertionFailure("Missing exptected analytics pdf input type")
            return
        }
        self.analyticsManager.track(event: .pageAdded(pdfInputType: currentAnalyticsPdfInputType, fileExtension: self.currentAnalyticsInputFileExtension))
        self.currentAnalyticsPdfInputType = nil
        self.currentAnalyticsInputFileExtension = nil
    }
}

enum PdfEditSaveError: LocalizedError {
    case unknown
    case noPages
    
    var errorDescription: String? {
        switch self {
        case .unknown: return String(localized: "Internal Error. Please try again later.")
        case .noPages: return String(localized: "Your pdf doesn't contain any pages.")
        }
    }
}
