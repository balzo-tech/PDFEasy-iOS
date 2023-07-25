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

enum MarginsOption: CaseIterable {
    case noMargins, mediumMargins, heavyMargins
}

enum PdfEditStartAction {
    case openFillWidget
    case openFillForm
    case openSignature
}

class PdfEditViewModel: ObservableObject {
    
    struct InputParameter {
        let pdfEditable: PdfEditable
        let startAction: PdfEditStartAction?
        let shouldShowCloseWarning: Binding<Bool>
    }
    
    enum EditMode: CaseIterable {
        case add, margins, compression
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
    @Published var signatureAddViewShow: Bool = false
    @Published var fillFormViewShow: Bool = false
    @Published var fillWidgetViewShow: Bool = false
    @Published var editMode: EditMode = .add
    @Published var marginsOption: MarginsOption = K.Misc.PdfDefaultMarginOption
    @Published var compression: CGFloat = K.Misc.PdfDefaultCompression
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
    
    @Injected(\.repository) private var repository
    @Injected(\.pdfCoordinator) private var coordinator
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    
    var shouldShowCloseWarning: Binding<Bool>
    var urlToFileToConvert: URL?
    var imageToConvert: UIImage?
    var scannerResult: ScannerResult?
    
    var pdf: Pdf? = nil
    
    var currentAnalyticsPdfInputType: AnalyticsPdfInputType? = nil
    var currentAnalyticsInputFileExtension: String? = nil
    var startAction: PdfEditStartAction? = nil
    
    var showFillWidgetButton: Bool { PDFUtility.hasPdfWidget(pdfEditable: self.pdfEditable) }
    
    private var lockedPdfEditable: PdfEditable? = nil
    
    init(inputParameter: InputParameter) {
        self.pdfEditable = inputParameter.pdfEditable
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
        guard self.pdfEditable.pdfDocument.pageCount > 0 else {
            self.pdfSaveError = .noPages
            return
        }
        
        let pdfDocument = self.pdfEditable.pdfDocument
        
        guard let data = pdfDocument.dataRepresentation() else {
            debugPrint(for: self, message: "Couldn't convert pdf document to data")
            self.pdfSaveError = .unknown
            return
        }
        do {
            let pdf = Pdf(context: self.repository.pdfManagedContext, pdfData: data, password: self.pdfEditable.password)
            self.pdf = pdf
            try self.repository.saveChanges()
            self.shouldShowCloseWarning.wrappedValue = false
            self.viewPdf()
        } catch {
            debugPrint(for: self, message: "Pdf save failed with error: \(error)")
            self.pdfSaveError = .saveFailed
        }
    }
    
    func showAddSignature() {
        self.signatureAddViewShow = true
    }
    
    func showFillForm() {
        self.fillFormViewShow = true
    }
    
    func showFillWidget() {
        self.fillWidgetViewShow = true
    }
    
    func viewPdf() {
        guard let pdf = self.pdf else {
            debugPrint(for: self, message: "Missing expected pdf")
            self.pdfSaveError = .unknown
            return
        }
        self.analyticsManager.track(event: .pdfEditCompleted(marginsOption: self.marginsOption, compressionValue: self.compression))
        self.coordinator.showViewer(pdf: pdf, marginOption: self.marginsOption, compression: self.compression)
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
    case saveFailed
    case noPages
    
    var errorDescription: String? {
        switch self {
        case .unknown: return "Internal Error. Please try again later."
        case .saveFailed: return "The pdf file couldn't be saved on your device. You can still view it and share it."
        case .noPages: return "Your pdf doesn't contain any pages."
        }
    }
}
