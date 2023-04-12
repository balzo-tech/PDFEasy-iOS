//
//  PdfEditViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import Factory
import UIKit

extension Container {
    var pdfEditViewModel: ParameterFactory<PdfEditable, PdfEditViewModel> {
        self { PdfEditViewModel(pdfEditable: $0) }.shared
    }
}

class PdfEditViewModel: ObservableObject {
    
    @Published var pdfEditable: PdfEditable
    @Published var pdfCurrentPageIndex: Int? = 0
    @Published var pdfThumbnails: [UIImage?] = []
    @Published var pdfSaveError: PdfEditSaveError? = nil
    
    
    @Injected(\.repository) private var repository
    @Injected(\.pdfCoordinator) private var coordinator
    
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
        // TODO
//        self.fileImagePickerShow = true
    }
    
    func openCamera() {
        // TODO
//        self.cameraShow = true
    }
    
    func openGallery() {
        // TODO
//        self.imagePickerShow = true
    }
    
    func save() {
        guard self.pdfEditable.pdfDocument.pageCount > 0 else {
            self.pdfSaveError = .noPages
            return
        }
        guard let data = self.pdfEditable.rawData else {
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
