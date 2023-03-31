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
import PDFKit
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
    
    @Published var asyncPdf: AsyncOperation<Data, SharedLocalizedError> = AsyncOperation(status: .empty) {
        didSet {
            if self.asyncPdf.success {
                self.pdfExportShow = true
            }
        }
    }
    
    @Published var pdfExportShow: Bool = false
    
    @Injected(\.repository) var repository
    
    func openImageInputPicker() {
        self.imageInputPickerShow = true
    }
    
    func scanPdf() {
        self.scannerShow = true
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
        self.fileDocPickerShow = true
    }
    
    func convertFileImage(fileImageUrl: URL) {
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
    
    func convertFileDoc(fileDocUrl: URL) {
        
        self.asyncPdf = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        Processor.generatePDF(from: fileDocUrl, options: [:]) { data, error in
            if let error = error {
                debugPrint(for: self, message: "Error converting word file. Error: \(error)")
                self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            } else if let data = data {
                self.asyncPdf = AsyncOperation(status: .data(data))
            } else {
                self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            }
        }
    }
    
    func convertUiImageToPdf(uiImage: UIImage) {
        self.asyncPdf = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        let pdfDocument = PDFDocument()
        
        guard let pdfPage = PDFPage(image: uiImage) else {
            self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            return
        }
        
        pdfDocument.insert(pdfPage, at: 0)
        
        guard let data = pdfDocument.dataRepresentation() else {
            self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            return
        }
        
        self.asyncPdf = AsyncOperation(status: .data(data))
    }
    
    func convertScanToPdf(scannerResult: ScannerResult) {
        
        self.scannerShow = false
        
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
                self.asyncPdf = AsyncOperation(status: .data(data))
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
                case .success(let profileImage?):
                    self.asyncImageLoading = AsyncOperation(status: .data(()))
                    self.convertUiImageToPdf(uiImage: profileImage.uiImage)
                case .success(nil):
                    self.asyncImageLoading = AsyncOperation(status: .empty)
                case .failure(let error):
                    let convertedError = ImportImageError.convertError(fromError: error)
                    self.asyncImageLoading = AsyncOperation(status: .error(convertedError))
                }
            }
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
