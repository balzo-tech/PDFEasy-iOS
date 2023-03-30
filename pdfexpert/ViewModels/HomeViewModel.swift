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
    let image: Image
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
        #if canImport(AppKit)
            guard let nsImage = NSImage(data: data) else {
                throw ImageTransferError.importFailed
            }
            let image = Image(nsImage: nsImage)
            return PickedImage(image: image)
        #elseif canImport(UIKit)
            guard let uiImage = UIImage(data: data) else {
                throw ImageTransferError.importFailed
            }
            let image = Image(uiImage: uiImage)
            return PickedImage(image: image)
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
    
    @Published var asyncImageLoading: AsyncOperation<Image, ImportImageError> = AsyncOperation(status: .empty)
    
    @Published var cameraShow: Bool = false
    
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
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB]
            bcf.countStyle = .file
            let memorySize = bcf.string(fromByteCount: Int64(fileData.count))
            debugPrint(for: self, message: "File fetched successfully. File size: \(memorySize)")
        } catch {
            debugPrint(for: self, message: "Error retrieving file. Error: \(error)")
        }
    }
    
    func convertUiImage(uiImage: UIImage) {
        debugPrint(for: self, message: "TODO: Convert image to pdf")
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
                    self.asyncImageLoading = AsyncOperation(status: .data(profileImage.image))
                    self.convertImage(image: profileImage.image)
                case .success(nil):
                    self.asyncImageLoading = AsyncOperation(status: .empty)
                case .failure(let error):
                    let convertedError = ImportImageError.convertError(fromError: error)
                    self.asyncImageLoading = AsyncOperation(status: .error(convertedError))
                }
            }
        }
    }
    
    private func convertImage(image: Image) {
        debugPrint(for: self, message: "TODO: Convert image to pdf")
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
