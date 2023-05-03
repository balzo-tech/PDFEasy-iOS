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

class PdfEditViewModel: ObservableObject {
    
    enum EditMode: CaseIterable {
        case add, margins
    }
    
    enum MarginsOption: CaseIterable {
        case noMargins, mediumMargins, heavyMargins
    }
    
    @Published var pdfEditable: PdfEditable
    @Published var pdfCurrentPageIndex: Int? = 0
    @Published var pdfThumbnails: [UIImage?] = []
    @Published var pdfSaveError: PdfEditSaveError? = nil
    
    @Published var fileImagePickerShow: Bool = false
    @Published var cameraShow: Bool = false
    @Published var imagePickerShow: Bool = false
    @Published var editMode: EditMode = .add
    @Published var marginsOption: MarginsOption = .noMargins
    
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
    
    @Injected(\.repository) private var repository
    @Injected(\.pdfCoordinator) private var coordinator
    
    var urlToImageToConvert: URL?
    var imageToConvert: UIImage?
    
    var pdf: Pdf? = nil
    
    init(pdfEditable: PdfEditable) {
        self.pdfEditable = pdfEditable
        for index in 0..<pdfEditable.pdfDocument.pageCount {
            let image = PDFUtility.generatePdfThumbnail(pdfDocument: pdfEditable.pdfDocument,
                                                        size: K.Misc.ThumbnailEditSize,
                                                        forPageIndex: index)
            self.pdfThumbnails.append(image)
        }
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
    }
    
    func openFileImagePicker() {
        self.fileImagePickerShow = true
    }
    
    func openCamera() {
        self.cameraShow = true
    }
    
    func openGallery() {
        self.imagePickerShow = true
    }
    
    func save() {
        guard self.pdfEditable.pdfDocument.pageCount > 0 else {
            self.pdfSaveError = .noPages
            return
        }
        
        let pdfDocument = PDFUtility.addMargins(toPdfDocument: self.pdfEditable.pdfDocument, horizontalMargin: self.marginsOption.horizontalMargin)
        
        guard let data = pdfDocument.dataRepresentation() else {
            debugPrint(for: self, message: "Couldn't convert pdf document to data")
            self.pdfSaveError = .unknown
            return
        }
        do {
            let pdf = Pdf(context: self.repository.pdfManagedContext, pdfData: data)
            self.pdf = pdf
            try self.repository.saveChanges()
            self.viewPdf()
        } catch {
            debugPrint(for: self, message: "Pdf save failed with error: \(error)")
            self.pdfSaveError = .saveFailed
        }
    }
    
    func viewPdf() {
        guard let pdf = self.pdf else {
            debugPrint(for: self, message: "Missing expected pdf")
            self.pdfSaveError = .unknown
            return
        }
        self.coordinator.showViewer(pdf: pdf)
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
