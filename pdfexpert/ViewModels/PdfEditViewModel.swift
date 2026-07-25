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

enum EditAction: CaseIterable {
    case password
    case compression
    case split
    case extract
    case export
    case ocr
    case pageNumbers
    case watermark
    case removeBlankPages
    case flatten
    case invertColors
    case permissions
    case metadata
}

class PdfEditViewModel: ObservableObject {
    
    struct InputParameter {
        let pdf: Pdf
        let startAction: PdfEditStartAction?
        let shouldShowCloseWarning: Binding<Bool>
    }
    
    @Published private(set)var pdf: Pdf
    @Published var pdfCurrentPageIndex: Int = 0
    @Published var pageImages: [UIImage] = []
    @Published var pdfThumbnails: [UIImage] = []
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

    @Published var cleanupAlertShow: Bool = false
    /// Message for the alert above; set right before it is shown.
    private(set) var cleanupAlertMessage: String = ""

    @Published var saveSuccessfulAlertShow: Bool = false
    
    @Published var pdfFilename: String {
        didSet {
            self.onPdfChanged()
        }
    }
    @Published var compression: CompressionOption {
        didSet {
            self.onPdfChanged()
        }
    }
    
    enum ActiveSheet: Identifiable {
        case camera, scanner, signature, fillForm, fillWidget, pageNumbers, watermark, metadata
        var id: Self { self }
    }

    @Published var activeSheet: ActiveSheet?
    
    @Published var editOptionListShow: Bool = false
    @Published var passwordTextFieldShow: Bool = false
    @Published var removePasswordAlertShow: Bool = false
    @Published var splitSuccessAlertShow: Bool = false
    @Published var extractSuccessAlertShow: Bool = false
    @Published var compressionShow: Bool = false
    @Published var ocrMonetizationShow: Bool = false
    @Published var pageNumbersMonetizationShow: Bool = false
    @Published var watermarkMonetizationShow: Bool = false
    @Published var rotateOptionsShow: Bool = false

    @Injected(\.repository) private var repository
    @Injected(\.mainCoordinator) private var mainCoordinator
    @Injected(\.pdfCoordinator) private var pdfCoordinator
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.pdfShareCoordinator) var pdfShareCoordinator
    @Injected(\.pdfSplitViewModel) var pdfSplitViewModel
    @Injected(\.pdfExtractViewModel) var pdfExtractViewModel
    @Injected(\.pdfExportViewModel) var pdfExportViewModel
    @Injected(\.pdfPermissionsViewModel) var pdfPermissionsViewModel

    lazy var pdfUnlockViewModel: PdfUnlockViewModel = {
        Container.shared.pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfSingleOutput: self.asyncSubject(\.asyncPdf)))
    }()

    // Office / iWork documents added as pages are converted on-device, with an optional
    // online fallback (see OfficeImportCoordinator). Replaces the former PSPDFKit call.
    lazy var officeImportCoordinator: OfficeImportCoordinator = {
        Container.shared.officeImportCoordinator(OfficeImportCoordinator.Params(asyncPdf: self.asyncSubject(\.asyncPdf)))
    }()
    
    // This boolean is set to true every time a change is applied to the original pdf.
    // TODO: Find a more robust solution
    var shouldShowCloseWarning: Binding<Bool>
    var urlToFileToConvert: URL?
    var imageToConvert: UIImage?
    var scannerResult: ScannerResult?
    
    var currentAnalyticsPdfInputType: AnalyticsPdfInputType? = nil
    var currentAnalyticsInputFileExtension: String? = nil
    var startAction: PdfEditStartAction? = nil
    // Set when OCR is gated behind the paywall, so it runs after a successful purchase.
    private var ocrPending: Bool = false
    // Same per-feature paywall flags for the page-number and watermark tools: the
    // tool opens after a successful purchase (see the respective monetization-close).
    private var pageNumbersPending: Bool = false
    private var watermarkPending: Bool = false
    
    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        self.pdfFilename = inputParameter.pdf.filename
        self.compression = inputParameter.pdf.compression
        self.startAction = inputParameter.startAction
        self.shouldShowCloseWarning = inputParameter.shouldShowCloseWarning
        self.refreshImages()
        self.refreshThumbnails()
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
                    self.rotateOptionsShow = true
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
        }
    }
    
    func deleteCurrentPage() {
        guard self.pdfThumbnails.count == self.pdf.pdfDocument.pageCount else {
            assertionFailure("Inconsistency error: pdf thumbnails count doesn't match pdf pages count")
            return
        }
        guard self.pageImages.count == self.pdf.pdfDocument.pageCount else {
            assertionFailure("Inconsistency error: pdf page images count doesn't match pdf pages count")
            return
        }
        let maxIndex = self.pdf.pdfDocument.pageCount
        
        guard self.pdfCurrentPageIndex >= 0, self.pdfCurrentPageIndex < maxIndex else {
            debugPrint(for: self, message: "Out of bound index!")
            return
        }
        self.pdf.pdfDocument.removePage(at: self.pdfCurrentPageIndex)
        self.pdfThumbnails.remove(at: self.pdfCurrentPageIndex)
        self.pageImages.remove(at: self.pdfCurrentPageIndex)
        
        let newMaxIndex = self.pdf.pdfDocument.pageCount
        
        if self.pdfCurrentPageIndex >= newMaxIndex {
            self.pdfCurrentPageIndex = (newMaxIndex > 0) ? newMaxIndex - 1 : 0
        }
        
        self.shouldShowCloseWarning.wrappedValue = true

        self.analyticsManager.track(event: .pageRemoved)
    }

    /// Rotates only the currently displayed page. Regenerates just that page's image
    /// and thumbnail (the full `refreshImages()`/`refreshThumbnails()` rebuilds every
    /// page and is a known perf problem on large documents).
    @MainActor
    func rotateCurrentPage(clockwise: Bool) {
        guard let page = self.pdf.pdfDocument.page(at: self.pdfCurrentPageIndex) else {
            return
        }
        PDFUtility.rotatePage(page, clockwise: clockwise)
        self.regenerateThumbnailEntries(at: self.pdfCurrentPageIndex)
        self.shouldShowCloseWarning.wrappedValue = true
        self.analyticsManager.track(event: .pageRotated(rotationType: .single))
    }

    /// Rotates every page in the document, then does the full images+thumbnails refresh
    /// (a per-page regeneration wouldn't be any cheaper here).
    @MainActor
    func rotateAllPages(clockwise: Bool) {
        for index in 0..<self.pdf.pdfDocument.pageCount {
            if let page = self.pdf.pdfDocument.page(at: index) {
                PDFUtility.rotatePage(page, clockwise: clockwise)
            }
        }
        self.refreshImages()
        self.refreshThumbnails()
        self.shouldShowCloseWarning.wrappedValue = true
        self.analyticsManager.track(event: .pageRotated(rotationType: .all))
    }

    /// Regenerates the page image and thumbnail for a single page, replacing the
    /// existing entries in place, using the shared single-page thumbnail helper.
    private func regenerateThumbnailEntries(at index: Int) {
        guard index >= 0, index < self.pdf.pdfDocument.pageCount else { return }
        if index < self.pageImages.count,
           let pageImage = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdf.pdfDocument,
                                                           size: nil,
                                                           forPageIndex: index) {
            self.pageImages[index] = pageImage
        }
        if index < self.pdfThumbnails.count,
           let thumbnail = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdf.pdfDocument,
                                                           size: K.Misc.ThumbnailEditSize,
                                                           forPageIndex: index) {
            self.pdfThumbnails[index] = thumbnail
        }
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
    
    @MainActor
    func handleEditAction(_ action: EditAction) {
        
        self.editOptionListShow = false

        // Defer to the next runloop so the edit-options sheet finishes dismissing
        // before the follow-up modal/alert is presented (replaces a fixed Task.sleep).
        DispatchQueue.main.async {
            switch action {
            case .password:
                if self.pdf.password != nil {
                    self.removePasswordAlertShow = true
                } else {
                    self.passwordTextFieldShow = true
                }
            case .compression:
                self.compressionShow = true
            case .split:
                self.pdfSplitViewModel.split(pdf: self.pdf, onSplitCompleted: { [weak self] in
                    self?.splitSuccessAlertShow = true
                })
            case .extract:
                self.pdfExtractViewModel.extract(pdf: self.pdf, onExtractCompleted: { [weak self] in
                    self?.extractSuccessAlertShow = true
                })
            case .export:
                self.pdfExportViewModel.export(pdf: self.pdf)
            case .ocr:
                self.startOcr()
            case .pageNumbers:
                self.startPageNumbers()
            case .watermark:
                self.startWatermark()
            case .removeBlankPages:
                self.runCleanup(.removeBlankPages)
            case .flatten:
                self.runCleanup(.flatten)
            case .invertColors:
                self.runCleanup(.invertColors)
            case .permissions:
                self.pdfPermissionsViewModel.run(pdf: self.pdf, onCompleted: nil)
            case .metadata:
                self.activeSheet = .metadata
            }
        }
    }

    /// Applies edited metadata coming back from the metadata editor. Metadata never
    /// affects rendering, so this deliberately avoids the heavy
    /// `refreshImages()`/`refreshThumbnails()` full rebuild that `updatePdf(pdf:)`
    /// does; it only swaps in the updated `Pdf` and marks the document dirty.
    func applyMetadata(pdf: Pdf) {
        self.pdf = pdf
        self.shouldShowCloseWarning.wrappedValue = true
    }

    /// Entry point for the OCR / searchable-PDF tool. OCR is a premium feature:
    /// non-subscribers see the paywall first and the OCR runs after a successful
    /// purchase (see `onOcrMonetizationClose`).
    @MainActor
    func startOcr() {
        if self.store.isPremium.value {
            self.performOcr()
        } else {
            self.ocrPending = true
            self.ocrMonetizationShow = true
        }
    }

    @MainActor
    func onOcrMonetizationClose() {
        let shouldRun = self.ocrPending && self.store.isPremium.value
        self.ocrPending = false
        if shouldRun {
            self.performOcr()
        }
    }

    @MainActor
    private func performOcr() {
        self.analyticsManager.track(event: .ocrStarted)
        OcrUtility.makeSearchable(pdf: self.pdf, asyncOperation: self.asyncSubject(\.asyncOcr))
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
                self.cleanupAlertMessage = removedCount > 0
                    ? String(localized: "Blank pages removed: \(removedCount)")
                    : String(localized: "No blank pages were found in your PDF.")
                self.analyticsManager.track(event: .blankPagesRemoved(count: removedCount))
            case .flatten:
                self.cleanupAlertMessage = String(localized: "Your PDF has been flattened. Annotations and form fields are now part of the page.")
                self.analyticsManager.track(event: .pdfFlattened)
            case .invertColors:
                self.cleanupAlertMessage = String(localized: "Colors have been inverted.")
                self.analyticsManager.track(event: .colorsInverted)
            }
            self.cleanupAlertShow = true
        })
    }

    /// Entry point for the page-number tool. Premium-gated exactly like OCR: the
    /// tool sheet opens immediately for subscribers, otherwise the paywall is shown
    /// and the sheet opens after a successful purchase (see `onPageNumbersMonetizationClose`).
    @MainActor
    func startPageNumbers() {
        if self.store.isPremium.value {
            self.activeSheet = .pageNumbers
        } else {
            self.pageNumbersPending = true
            self.pageNumbersMonetizationShow = true
        }
    }

    @MainActor
    func onPageNumbersMonetizationClose() {
        let shouldOpen = self.pageNumbersPending && self.store.isPremium.value
        self.pageNumbersPending = false
        if shouldOpen {
            // Defer so the paywall cover finishes dismissing before the tool cover
            // is presented (two fullScreenCovers on the same hierarchy).
            DispatchQueue.main.async {
                self.activeSheet = .pageNumbers
            }
        }
    }

    /// Entry point for the watermark tool. Same premium gate as the page-number tool.
    @MainActor
    func startWatermark() {
        if self.store.isPremium.value {
            self.activeSheet = .watermark
        } else {
            self.watermarkPending = true
            self.watermarkMonetizationShow = true
        }
    }

    @MainActor
    func onWatermarkMonetizationClose() {
        let shouldOpen = self.watermarkPending && self.store.isPremium.value
        self.watermarkPending = false
        if shouldOpen {
            DispatchQueue.main.async {
                self.activeSheet = .watermark
            }
        }
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
        } else if let scannerResult = self.scannerResult {
            self.scannerResult = nil
            PdfScanUtility.convertScan(scannerResult: scannerResult, asyncOperation: self.asyncSubject(\.asyncPdf))
        }
    }
    
    func updatePdf(pdf: Pdf) {
        // TODO: Update thumbnails only for changed pages
        self.pdf = pdf
        self.shouldShowCloseWarning.wrappedValue = true
        self.refreshThumbnails()
        self.refreshImages()
    }
    
    func handlePageReordering(fromIndex: Int, toIndex: Int) {
        if fromIndex != toIndex {
            // exchangePage throws an exception if used after pages are added. Apparently it doesn't update its internal indices when adding pages,
            // which it relies upon to perform the swap. A manual workaround using removePage and insert methods seems to work fine, though.
//            self.pdf.pdfDocument.exchangePage(at: fromIndex, withPageAt: toIndex)
            if let toPage = self.pdf.pdfDocument.page(at: toIndex), let fromPage = self.pdf.pdfDocument.page(at: fromIndex) {
                self.pdf.pdfDocument.removePage(at: fromIndex)
                self.pdf.pdfDocument.insert(toPage, at: fromIndex)
                self.pdf.pdfDocument.removePage(at: toIndex)
                self.pdf.pdfDocument.insert(fromPage, at: toIndex)
                
                self.pdfThumbnails.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: (toIndex > fromIndex ? (toIndex + 1) : toIndex))
                self.pageImages.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: (toIndex > fromIndex ? (toIndex + 1) : toIndex))
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
        self.pdfShareCoordinator.share(pdf: self.pdf, applyPostProcess: true, onComplete: { [weak self] in
            self?.pdfCoordinator.startReview()
        })
    }
    
    private func onPdfChanged() {
        if self.pdf.filename != self.pdfFilename {
            self.pdf.updateFilename(self.pdfFilename)
            self.shouldShowCloseWarning.wrappedValue = true
            self.analyticsManager.track(event: .pdfRenamed)
        }
        if self.pdf.compression != self.compression {
            self.pdf.updateCompression(self.compression)
            self.shouldShowCloseWarning.wrappedValue = true
            self.analyticsManager.track(event: .compressionOptionChanged(compressionOption: self.compression))
        }
    }
    
    @MainActor
    private func convertFileByUrl(fileUrl: URL) {
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
        let pageImage = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdf.pdfDocument,
                                                        size: nil,
                                                        forPageIndex: self.pdf.pdfDocument.pageCount - 1)
        let thumbnail = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdf.pdfDocument,
                                                    size: K.Misc.ThumbnailEditSize,
                                                    forPageIndex: self.pdf.pdfDocument.pageCount - 1)
        if let pageImage = pageImage, let thumbnail = thumbnail {
            self.pageImages.append(pageImage)
            self.pdfThumbnails.append(thumbnail)
        }
        self.shouldShowCloseWarning.wrappedValue = true
        self.trackPageAddedEvent()
    }
    
    private func appendPdfToPdf(pdf: Pdf) {
        PDFUtility.appendPdfDocument(pdf.pdfDocument, toPdfDocument: self.pdf.pdfDocument)
        let pageImages = PDFUtility.generatePdfThumbnails(pdfDocument: pdf.pdfDocument, size: nil).compactMap { $0 }
        self.pageImages.append(contentsOf: pageImages)
        let thumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: pdf.pdfDocument, size: K.Misc.ThumbnailEditSize).compactMap { $0 }
        self.pdfThumbnails.append(contentsOf: thumbnails)
        self.shouldShowCloseWarning.wrappedValue = true
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
    
    private func refreshImages() {
        self.pageImages = PDFUtility.generatePdfThumbnails(pdfDocument: self.pdf.pdfDocument, size: nil).compactMap { $0 }
    }
    
    private func refreshThumbnails() {
        self.pdfThumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: self.pdf.pdfDocument, size: K.Misc.ThumbnailEditSize).compactMap { $0 }
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
        case .unknown: return "Internal Error. Please try again later."
        case .noPages: return "Your pdf doesn't contain any pages."
        }
    }
}
