//
//  HomeViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import Foundation
import Factory
import SwiftUI
import PhotosUI
import PSPDFKit
import WeScan

extension Container {
    var homeViewModel: Factory<HomeViewModel> {
        self { HomeViewModel() }.shared
    }
}

enum ImageTransferError: LocalizedError {
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .importFailed: return "Couldn't import the selected photo."
        }
    }
}

struct PickedImage: Transferable {
    let uiImage: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
        #if canImport(UIKit)
            guard let uiImage = UIImage(data: data) else {
                throw ImageTransferError.importFailed
            }
            return PickedImage(uiImage: uiImage)
        #else
            throw ImageTransferError.importFailed
        #endif
        }
    }
}

public class HomeViewModel : ObservableObject {
    
    @Published var monetizationShow: Bool = false
    
    @Published var imageInputPickerShow: Bool = false
    @Published var fileImagePickerShow: Bool = false
    @Published var fileDocPickerShow: Bool = false
    
    @Published var imagePickerShow: Bool = false
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
    
    @Published var cameraShow: Bool = false
    @Published var scannerShow: Bool = false
    @Published var cameraPermissionDeniedShow: Bool = false
    
    @Published var asyncPdf: AsyncOperation<PdfEditable, SharedLocalizedError> = AsyncOperation(status: .empty) {
        didSet {
            if self.asyncPdf.success {
                self.pdfFlowShow = true
            }
        }
    }
    
    @Published var pdfFlowShow: Bool = false
    
    @Injected(\.store) private var store
    
    var urlToImageToConvert: URL?
    var urlToDocToConvert: URL?
    var imageToConvert: UIImage?
    var scannerResult: ScannerResult?
    
    @MainActor
    func onAppear() {
        Task {
            try await self.store.refreshAll()
        }
    }
    
    func openImageInputPicker() {
        self.imageInputPickerShow = true
    }
    
    func scanPdf() {
        if self.store.isPremium.value {
            self.showScanner()
        } else {
            self.monetizationShow = true
        }
    }
    
    func openFileImagePicker() {
        self.imageInputPickerShow = false
        self.fileImagePickerShow = true
    }
    
    func openCamera() {
        self.imageInputPickerShow = false
        self.cameraShow = true
    }
    
    func openGallery() {
        self.imageInputPickerShow = false
        self.imagePickerShow = true
    }
    
    func openFileDocPicker() {
        if self.store.isPremium.value {
            self.fileDocPickerShow = true
        } else {
            self.monetizationShow = true
        }
    }
    
    @MainActor
    func convert() {
        if let urlToImageToConvert = self.urlToImageToConvert {
            self.urlToImageToConvert = nil
            self.convertFileImageByURL(fileImageUrl: urlToImageToConvert)
        } else if let urlToDocToConvert = self.urlToDocToConvert {
            self.urlToDocToConvert = nil
            self.convertFileDocByUrl(fileDocUrl: urlToDocToConvert)
        } else if let imageToConvert = self.imageToConvert {
            self.imageToConvert = nil
            self.convertUiImageToPdf(uiImage: imageToConvert)
        } else if let scannerResult = self.scannerResult {
            self.scannerResult = nil
            self.convertScan(scannerResult: scannerResult)
        }
    }
    
    @MainActor
    private func convertFileImageByURL(fileImageUrl: URL) {
        do {
            let imageData = try Data(contentsOf: fileImageUrl)
            guard let uiImage = UIImage(data: imageData) else {
                self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
                return
            }
            self.convertUiImageToPdf(uiImage: uiImage)
        } catch {
            debugPrint(for: self, message: "Error retrieving file. Error: \(error)")
            self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
        }
    }
    
    @MainActor
    private func convertFileDocByUrl(fileDocUrl: URL) {
        
        self.asyncPdf = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        Processor.generatePDF(from: fileDocUrl, options: [:]) { data, error in
            if let error = error {
                debugPrint(for: self, message: "Error converting word file. Error: \(error)")
                self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            } else if let data = data, let pdfEditable = PdfEditable(data: data) {
                self.asyncPdf = AsyncOperation(status: .data(pdfEditable))
            } else {
                self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            }
        }
    }
    
    @MainActor
    func convertScan(scannerResult: ScannerResult) {
        guard let imageScannerResult = scannerResult.results else {
            if let error = scannerResult.error {
                debugPrint(for: self, message: "Scan failed. Error: \(error)")
                self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            } else {
                self.asyncPdf = AsyncOperation(status: .empty)
            }
            return
        }
        
        self.asyncPdf = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        var scan = imageScannerResult.croppedScan
        
        if imageScannerResult.doesUserPreferEnhancedScan, let enhancedScan = imageScannerResult.enhancedScan {
            scan = enhancedScan
        }
        
        scan.generatePDFData { result in
            switch result {
            case .success(let data):
                guard let pdfEditable = PdfEditable(data: data) else {
                    self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
                    return
                }
                self.asyncPdf = AsyncOperation(status: .data(pdfEditable))
            case .failure(let error):
                debugPrint(for: self, message: "Scan to pdf conversion failed. Error: \(error.localizedDescription)")
                self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            }
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
                    self.convertUiImageToPdf(uiImage: image.uiImage)
                case .success(nil):
                    self.asyncImageLoading = AsyncOperation(status: .empty)
                case .failure(let error):
                    let convertedError = ImportImageError.convertError(fromError: error)
                    self.asyncImageLoading = AsyncOperation(status: .error(convertedError))
                }
            }
        }
    }
    
    private func convertUiImageToPdf(uiImage: UIImage) {
        let pdfDocument = PDFUtility.convertUiImageToPdf(uiImage: uiImage)
        self.asyncPdf = AsyncOperation(status: .data(PdfEditable(pdfDocument: pdfDocument)))
    }
    
    private func showScanner() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            self.scannerShow = true
        default:
            self.cameraPermissionDeniedShow = true
        }
    }
}

enum ImportImageError: LocalizedError, UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        }
    }
}
