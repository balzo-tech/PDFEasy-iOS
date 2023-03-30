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
//import PSPDFKit
import PDFKit

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
    
    @Published var asyncPdf: AsyncOperation<Data, SharedLocalizedError> = AsyncOperation(status: .empty) {
        didSet {
            if self.asyncPdf.success {
                self.pdfExportShow = true
            }
        }
    }
    
    @Published var pdfExportShow: Bool = false
    
//    private var pdfDelegate: PDFDelegate?
//    private var processor: Processor?
    
    @Injected(\.repository) var repository
    
    func openImageInputPicker() {
        self.imageInputPickerShow = true
    }
    
    func scanPdf() {
        debugPrint(for: self, message: "TODO: Open Scanner")
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
        debugPrint(for: self, message: "TODO: Convert Doc File")
    }
    
    func convertUiImageToPdf(uiImage: UIImage) {
        self.asyncPdf = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        let pdfDocument = PDFDocument()
        let pdfPage = PDFPage(image: uiImage)
        pdfDocument.insert(pdfPage!, at: 0)
        guard let data = pdfDocument.dataRepresentation() else {
            self.asyncPdf = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
            return
        }
        self.asyncPdf = AsyncOperation(status: .data(data))
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

typealias PDFCreationSuccess = ((Data) -> ())
typealias PDFCreationFailure = ((Error) -> ())

//class PDFDelegate: NSObject, ProcessorDelegate {
//
//    var onPdfSuccess: PDFCreationSuccess
//    var onPdfError: PDFCreationFailure
//
//    init(onPdfSuccess: @escaping PDFCreationSuccess, onPdfError: @escaping PDFCreationFailure) {
//        self.onPdfSuccess = onPdfSuccess
//        self.onPdfError = onPdfError
//    }
//
//    func processor(_ processor: Processor, didProcessPage currentPage: UInt, totalPages: UInt) {
//        if currentPage == totalPages {
//            do {
//                let pdfData = try processor.data()
//                self.onPdfSuccess(pdfData)
//            } catch {
//                self.onPdfError(error)
//            }
//        }
//    }
//}
