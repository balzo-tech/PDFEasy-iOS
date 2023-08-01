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
import PSPDFKit

extension Container {
    var pdfEditViewModel: ParameterFactory<PdfEditViewModel.InputParameter, PdfEditViewModel> {
        self { PdfEditViewModel(inputParameter: $0) }
    }
}

enum PdfEditStartAction {
    case openFillWidget
    case openFillForm
    case openSignature
}

enum EditAction: CaseIterable {
    case password
    case compression
}

class PdfEditViewModel: ObservableObject {
    
    struct InputParameter {
        let pdfEditable: PdfEditable
        let startAction: PdfEditStartAction?
        let shouldShowCloseWarning: Binding<Bool>
    }
    
    @Published private(set)var pdfEditable: PdfEditable
    @Published var pdfCurrentPageIndex: Int = 0
    @Published var pageImages: [UIImage] = []
    @Published var pdfThumbnails: [UIImage] = []
    @Published var pdfSaveError: PdfEditSaveError? = nil
    @Published var filePickerShow: Bool = false
    @Published var cameraShow: Bool = false
    @Published var imagePickerShow: Bool = false
    @Published var scannerShow: Bool = false
    @Published var cameraPermissionDeniedShow: Bool = false
    
    @Published var pdfPasswordInputShow: Bool = false
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
    @Published var asyncPdf: AsyncOperation<PdfEditable, PdfEditableError> = AsyncOperation(status: .empty) {
        didSet {
            if let pdfEditable = self.asyncPdf.data  {
                self.appendPdfEditableToPdf(pdfEditable: pdfEditable)
                self.asyncPdf = AsyncOperation(status: .empty)
            }
        }
    }
    
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
    
    @Published var signatureAddViewShow: Bool = false
    @Published var fillFormViewShow: Bool = false
    @Published var fillWidgetViewShow: Bool = false
    
    @Published var editOptionListShow: Bool = false
    @Published var passwordTextFieldShow: Bool = false
    @Published var removePasswordAlertShow: Bool = false
    @Published var compressionShow: Bool = false
    
    @Injected(\.repository) private var repository
    @Injected(\.mainCoordinator) private var mainCoordinator
    @Injected(\.analyticsManager) private var analyticsManager
    
    var shouldShowCloseWarning: Binding<Bool>
    var urlToFileToConvert: URL?
    var imageToConvert: UIImage?
    var scannerResult: ScannerResult?
    
    var currentAnalyticsPdfInputType: AnalyticsPdfInputType? = nil
    var currentAnalyticsInputFileExtension: String? = nil
    var startAction: PdfEditStartAction? = nil
    
    var showFillWidgetButton: Bool { PDFUtility.hasPdfWidget(pdfEditable: self.pdfEditable) }
    
    let pdfShareCoordinator = Container.shared.pdfShareCoordinator(PdfShareCoordinator.Params(applyPostProcess: true))
    
    private var lockedPdfEditable: PdfEditable? = nil
    
    init(inputParameter: InputParameter) {
        self.pdfEditable = inputParameter.pdfEditable
        self.pdfFilename = inputParameter.pdfEditable.filename
        self.compression = inputParameter.pdfEditable.compression
        self.startAction = inputParameter.startAction
        self.shouldShowCloseWarning = inputParameter.shouldShowCloseWarning
        self.refreshImages()
        self.refreshThumbnails()
    }
    
    @MainActor
    func onAppear() {
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            
            if let startAction = self.startAction {
                switch startAction {
                case .openFillWidget:
                    if PDFUtility.hasPdfWidget(pdfEditable: self.pdfEditable) {
                        self.fillWidgetViewShow = true
                    } else {
                        self.missingWidgetWarningShow = true
                    }
                case .openFillForm:
                    self.fillFormViewShow = true
                case .openSignature:
                    self.signatureAddViewShow = true
                }
            }
            self.startAction = nil
        }
    }
    
    func deletePage(atIndex index: Int) {
        guard self.pdfThumbnails.count == self.pdfEditable.pdfDocument.pageCount else {
            assertionFailure("Inconsistency error: pdf thumbnails count doesn't match pdf pages count")
            return
        }
        guard self.pageImages.count == self.pdfEditable.pdfDocument.pageCount else {
            assertionFailure("Inconsistency error: pdf page images count doesn't match pdf pages count")
            return
        }
        let maxIndex = self.pdfEditable.pdfDocument.pageCount
        
        guard index >= 0, index < maxIndex else {
            debugPrint(for: self, message: "Out of bound index!")
            return
        }
        self.pdfEditable.pdfDocument.removePage(at: index)
        self.pdfThumbnails.remove(at: index)
        self.pageImages.remove(at: index)
        
        let newMaxIndex = self.pdfEditable.pdfDocument.pageCount
        
        if self.pdfCurrentPageIndex >= newMaxIndex {
            self.pdfCurrentPageIndex = (newMaxIndex > 0) ? newMaxIndex - 1 : 0
        }
        
        self.analyticsManager.track(event: .pageRemoved)
    }
    
    func openFilePicker() {
        self.filePickerShow = true
        self.currentAnalyticsPdfInputType = .file
    }
    
    func openCamera() {
        self.cameraShow = true
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
        self.signatureAddViewShow = true
    }
    
    func showFillForm() {
        self.fillFormViewShow = true
    }
    
    func showFillWidget() {
        if PDFUtility.hasPdfWidget(pdfEditable: self.pdfEditable) {
            self.fillWidgetViewShow = true
        } else {
            self.missingWidgetWarningShow = true
        }
    }
    
    @MainActor
    func handleEditAction(_ action: EditAction) {
        
        self.editOptionListShow = false
        
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            
            switch action {
            case .password:
                if self.pdfEditable.password != nil {
                    self.removePasswordAlertShow = true
                } else {
                    self.passwordTextFieldShow = true
                }
            case .compression: self.compressionShow = true
            }
        }
    }
    
    func setPassword(_ password: String) {
        self.internalSetPassword(password)
        debugPrint(for: self, message: "New password: \(password)")
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
    
    func updatePdf(pdfEditable: PdfEditable) {
        // TODO: Update thumbnails only for changed pages
        self.pdfEditable = pdfEditable
        self.refreshThumbnails()
        self.refreshImages()
    }
    
    func handlePageReordering(fromIndex: Int, toIndex: Int) {
        if fromIndex != toIndex {
            // exchangePage throws an exception if used after pages are added. Apparently it doesn't update its internal indices when adding pages,
            // which it relies upon to perform the swap. A manual workaround using removePage and insert methods seems to work fine, though.
//            self.pdfEditable.pdfDocument.exchangePage(at: fromIndex, withPageAt: toIndex)
            if let toPage = self.pdfEditable.pdfDocument.page(at: toIndex), let fromPage = self.pdfEditable.pdfDocument.page(at: fromIndex) {
                self.pdfEditable.pdfDocument.removePage(at: fromIndex)
                self.pdfEditable.pdfDocument.insert(toPage, at: fromIndex)
                self.pdfEditable.pdfDocument.removePage(at: toIndex)
                self.pdfEditable.pdfDocument.insert(fromPage, at: toIndex)
                
                self.pdfThumbnails.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: (toIndex > fromIndex ? (toIndex + 1) : toIndex))
                self.pageImages.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: (toIndex > fromIndex ? (toIndex + 1) : toIndex))
                if self.pdfCurrentPageIndex == fromIndex {
                    self.pdfCurrentPageIndex = toIndex
                } else if self.pdfCurrentPageIndex == toIndex {
                    self.pdfCurrentPageIndex = fromIndex
                }
            }
        }
    }
    
    private func internalSave() throws {
        guard self.pdfEditable.pdfDocument.pageCount > 0 else {
            throw PdfEditSaveError.noPages
        }
        self.pdfEditable = try self.repository.savePdf(pdfEditable: self.pdfEditable)
        self.shouldShowCloseWarning.wrappedValue = false
    }
    
    private func internalShare() {
        self.pdfShareCoordinator.share(pdf: self.pdfEditable)
    }
    
    private func onPdfChanged() {
        if self.pdfEditable.filename != self.pdfFilename {
            self.pdfEditable.updateFilename(self.pdfFilename)
        }
        if self.pdfEditable.compression != self.compression {
            self.pdfEditable.updateCompression(self.compression)
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
            self.asyncPdf = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
            Processor.generatePDF(from: fileUrl, options: [:]) { data, error in
                if let error = error {
                    debugPrint(for: self, message: "Error converting word file. Error: \(error)")
                    self.asyncPdf = AsyncOperation(status: .error(.unknownError))
                } else if let data = data, let pdfEditable = PdfEditable(data: data) {
                    self.currentAnalyticsInputFileExtension = fileUrl.pathExtension
                    self.asyncPdf = AsyncOperation(status: .data(pdfEditable))
                } else {
                    self.asyncPdf = AsyncOperation(status: .error(.unknownError))
                }
            }
        }
    }
    
    @MainActor
    func importPdf(pdfUrl: URL) {
        guard let pdfEditable = PdfEditable(pdfUrl: pdfUrl) else {
            assertionFailure("Missing expected file for give url")
            return
        }
        
        if pdfEditable.pdfDocument.isLocked {
            self.lockedPdfEditable = pdfEditable
            self.pdfPasswordInputShow = true
        } else {
            self.currentAnalyticsInputFileExtension = pdfUrl.pathExtension
            self.asyncPdf = PDFUtility.decryptFile(pdfEditable: pdfEditable)
        }
    }
    
    @MainActor
    func importLockedPdf(password: String) {
        guard let pdfEditable = self.lockedPdfEditable else {
            assertionFailure("Missing expected locked pdf")
            return
        }
        self.currentAnalyticsInputFileExtension = "pdf"
        self.asyncPdf = PDFUtility.decryptFile(pdfEditable: pdfEditable, password: password)
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
        PDFUtility.appendImageToPdfDocument(pdfDocument: self.pdfEditable.pdfDocument, uiImage: uiImage)
        let pageImage = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdfEditable.pdfDocument,
                                                        size: nil,
                                                        forPageIndex: self.pdfEditable.pdfDocument.pageCount - 1)
        let thumbnail = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdfEditable.pdfDocument,
                                                    size: K.Misc.ThumbnailEditSize,
                                                    forPageIndex: self.pdfEditable.pdfDocument.pageCount - 1)
        if let pageImage = pageImage, let thumbnail = thumbnail {
            self.pageImages.append(pageImage)
            self.pdfThumbnails.append(thumbnail)
        }
        self.trackPageAddedEvent()
    }
    
    private func appendPdfEditableToPdf(pdfEditable: PdfEditable) {
        PDFUtility.appendPdfDocument(pdfEditable.pdfDocument, toPdfDocument: self.pdfEditable.pdfDocument)
        let pageImages = PDFUtility.generatePdfThumbnails(pdfDocument: pdfEditable.pdfDocument, size: nil).compactMap { $0 }
        self.pageImages.append(contentsOf: pageImages)
        let thumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: pdfEditable.pdfDocument, size: K.Misc.ThumbnailEditSize).compactMap { $0 }
        self.pdfThumbnails.append(contentsOf: thumbnails)
        self.trackPageAddedEvent()
    }
    
    private func showScanner() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            self.scannerShow = true
        default:
            self.cameraPermissionDeniedShow = true
        }
    }
    
    private func internalSetPassword(_ password: String?) {
        self.pdfEditable.updatePassword(password)
        self.objectWillChange.send()
    }
    
    private func refreshImages() {
        self.pageImages = PDFUtility.generatePdfThumbnails(pdfDocument: self.pdfEditable.pdfDocument, size: nil).compactMap { $0 }
    }
    
    private func refreshThumbnails() {
        self.pdfThumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: self.pdfEditable.pdfDocument, size: K.Misc.ThumbnailEditSize).compactMap { $0 }
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
