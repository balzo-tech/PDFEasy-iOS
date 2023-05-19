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
    var pdfEditViewModel: ParameterFactory<PdfEditable, PdfEditViewModel> {
        self { PdfEditViewModel(pdfEditable: $0) }.shared
    }
}

enum MarginsOption: CaseIterable {
    case noMargins, mediumMargins, heavyMargins
}

class PdfEditViewModel: ObservableObject {
    
    enum EditMode: CaseIterable {
        case add, margins, compression
    }
    
    @Published private(set)var pdfEditable: PdfEditable
    @Published var pdfCurrentPageIndex: Int? = 0
    @Published var pdfThumbnails: [UIImage?] = []
    @Published var pdfSaveError: PdfEditSaveError? = nil
    
    @Published var fileImagePickerShow: Bool = false
    @Published var cameraShow: Bool = false
    @Published var imagePickerShow: Bool = false
    @Published var scannerShow: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var cameraPermissionDeniedShow: Bool = false
    @Published var signatureAddViewShow: Bool = false
    @Published var editMode: EditMode = .add
    @Published var marginsOption: MarginsOption = K.Misc.PdfDefaultMarginOption
    @Published var compression: CGFloat = K.Misc.PdfDefaultCompression
    
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
    
    @Published var asyncImageLoading: AsyncOperation<(), ImportImageError> = AsyncOperation(status: .empty)
    @Published var asyncPdf: AsyncOperation<PdfEditable, SharedLocalizedError> = AsyncOperation(status: .empty) {
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
    
    var urlToImageToConvert: URL?
    var imageToConvert: UIImage?
    var scannerResult: ScannerResult?
    
    var pdf: Pdf? = nil
    
    var currentAnalyticsPdfInputType: AnalyticsPdfInputType? = nil
    var currentInputFileExtension: String? = nil
    
    init(pdfEditable: PdfEditable) {
        self.pdfEditable = pdfEditable
        self.pdfThumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: pdfEditable.pdfDocument, size: K.Misc.ThumbnailEditSize)
    }
    
    func deletePage(atIndex index: Int) {
        guard self.pdfThumbnails.count == self.pdfEditable.pdfDocument.pageCount else {
            assertionFailure("Inconsistency error: pdf thumbnails count doesn't match pdf pages count")
            return
        }
        let maxIndex = self.pdfEditable.pdfDocument.pageCount
        
        guard index >= 0, index < maxIndex else {
            debugPrint(for: self, message: "Out of bound index!")
            return
        }
        self.pdfEditable.pdfDocument.removePage(at: index)
        self.pdfThumbnails.remove(at: index)
        
        let newMaxIndex = self.pdfEditable.pdfDocument.pageCount
        
        if nil != self.pdfCurrentPageIndex, index >= newMaxIndex {
            self.pdfCurrentPageIndex = (newMaxIndex > 0) ? newMaxIndex - 1 : nil
        }
        
        self.analyticsManager.track(event: .pageRemoved)
    }
    
    func openFileImagePicker() {
        self.fileImagePickerShow = true
        self.currentAnalyticsPdfInputType = .fileImage
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
        if self.store.isPremium.value {
            self.showScanner()
        } else {
            self.monetizationShow = true
        }
    }
    
    func save() {
        guard self.pdfEditable.pdfDocument.pageCount > 0 else {
            self.pdfSaveError = .noPages
            return
        }
        
        let pdfDocument = PDFUtility.applyPostProcess(toPdfDocument: self.pdfEditable.pdfDocument,
                                                      horizontalMargin: self.marginsOption.horizontalMargin,
                                                      quality: 1.0 - self.compression)
        
        guard let data = pdfDocument.dataRepresentation() else {
            debugPrint(for: self, message: "Couldn't convert pdf document to data")
            self.pdfSaveError = .unknown
            return
        }
        do {
            let pdf = Pdf(context: self.repository.pdfManagedContext, pdfData: data, password: self.pdfEditable.password)
            self.pdf = pdf
            try self.repository.saveChanges()
            self.viewPdf()
        } catch {
            debugPrint(for: self, message: "Pdf save failed with error: \(error)")
            self.pdfSaveError = .saveFailed
        }
    }
    
    func showAddSignature() {
        self.signatureAddViewShow = true
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
    
    func getCurrentPageImage(withSize size: CGSize) -> UIImage? {
        guard let pdfCurrentPageIndex = self.pdfCurrentPageIndex else {
            return nil
        }
        return PDFUtility.generatePdfThumbnail(pdfDocument: self.pdfEditable.pdfDocument,
                                               size: size,
                                               forPageIndex: pdfCurrentPageIndex)
    }
    
    @MainActor
    func convert() {
        if let urlToImageToConvert = self.urlToImageToConvert {
            self.urlToImageToConvert = nil
            self.convertFileImageByURL(fileImageUrl: urlToImageToConvert)
        } else if let imageToConvert = self.imageToConvert {
            self.imageToConvert = nil
            self.appendUiImageToPdf(uiImage: imageToConvert)
        } else if let scannerResult = self.scannerResult {
            self.scannerResult = nil
            PdfScanUtility.convertScan(scannerResult: scannerResult, asyncOperation: self.asyncSubject(\.asyncPdf))
        }
    }
    
    func updatePdfWithSignatures(pdfEditable: PdfEditable) {
        // TODO: Update thumbnails only for pages with new signatures added
        self.pdfEditable = pdfEditable
        self.refreshThumbnails()
    }
    
    @MainActor
    private func convertFileImageByURL(fileImageUrl: URL) {
        do {
            let imageData = try Data(contentsOf: fileImageUrl)
            guard let uiImage = UIImage(data: imageData) else {
                self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
                return
            }
            self.currentInputFileExtension = fileImageUrl.pathExtension
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
                    let convertedError = ImportImageError.convertError(fromError: error)
                    self.asyncImageLoading = AsyncOperation(status: .error(convertedError))
                }
            }
        }
    }
    
    private func appendUiImageToPdf(uiImage: UIImage) {
        PDFUtility.appendImageToPdfDocument(pdfDocument: self.pdfEditable.pdfDocument, uiImage: uiImage)
        let image = PDFUtility.generatePdfThumbnail(pdfDocument: self.pdfEditable.pdfDocument,
                                                    size: K.Misc.ThumbnailEditSize,
                                                    forPageIndex: self.pdfEditable.pdfDocument.pageCount - 1)
        self.pdfThumbnails.append(image)
        self.trackPageAddedEvent()
    }
    
    private func appendPdfEditableToPdf(pdfEditable: PdfEditable) {
        PDFUtility.appendPdfDocument(pdfEditable.pdfDocument, toPdfDocument: self.pdfEditable.pdfDocument)
        let thumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: pdfEditable.pdfDocument, size: K.Misc.ThumbnailEditSize)
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
    
    private func refreshThumbnails() {
        self.pdfThumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: self.pdfEditable.pdfDocument, size: K.Misc.ThumbnailEditSize)
    }
    
    private func trackPageAddedEvent() {
        guard let currentAnalyticsPdfInputType = self.currentAnalyticsPdfInputType else {
            assertionFailure("Missing exptected analytics pdf input type")
            return
        }
        self.analyticsManager.track(event: .pageAdded(pdfInputType: currentAnalyticsPdfInputType, fileExtension: self.currentInputFileExtension))
        self.currentAnalyticsPdfInputType = nil
        self.currentInputFileExtension = nil
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
