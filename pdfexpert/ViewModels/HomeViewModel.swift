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
    
    @Published var imageToPdfPickerShow: Bool = false
    @Published var filePickerShow: Bool = false
    
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
    
    @Published var asyncPdf: AsyncOperation<Data, SharedLocalizedError> = AsyncOperation(status: .empty)
    
//    private var pdfDelegate: PDFDelegate?
//    private var processor: Processor?
    
    @Injected(\.repository) var repository
    
    func convertImageToPdf() {
        self.imageToPdfPickerShow = true
    }
    
    func convertWordToPdf() {
        debugPrint(for: self, message: "TODO: Open File Picker")
    }
    
    func scanPdf() {
        debugPrint(for: self, message: "TODO: Open Scanner")
    }
    
    func openFilePicker() {
        self.imageToPdfPickerShow = false
        self.filePickerShow = true
    }
    
    func openCamera() {
        self.imageToPdfPickerShow = false
        self.cameraShow = true
    }
    
    func openGallery() {
        self.imageToPdfPickerShow = false
        self.imagePickerShow = true
    }
    
    func convertFile(fileUrl: URL) {
        do {
            let fileData = try Data(contentsOf: fileUrl)
            guard let uiImage = UIImage(data: fileData) else {
                self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
                return
            }
            self.convertUiImage(uiImage: uiImage)
        } catch {
            debugPrint(for: self, message: "Error retrieving file. Error: \(error)")
            self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
        }
    }
    
    func convertUiImage(uiImage: UIImage) {
        
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
