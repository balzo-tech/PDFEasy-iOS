//
//  ChatPdfSelectionViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import Foundation
import Factory
import PhotosUI
import PSPDFKit

extension Container {
    var chatPdfSelectionViewModel: Factory<ChatPdfSelectionViewModel> {
        self { ChatPdfSelectionViewModel() }
    }
}

class ChatPdfSelectionViewModel: ObservableObject {
    
    @Published var importOptionGroup: ImportOptionGroup? = nil
    @Published var importFileOption: ImportFileOption? = nil
    
    @Published var pdfPasswordInputShow: Bool = false
    
    @Published var scannerShow: Bool = false
    @Published var cameraPermissionDeniedShow: Bool = false
    
    @Published var asyncImportPdf: AsyncOperation<PdfEditable, PdfEditableError> = AsyncOperation(status: .empty) {
        didSet {
            if let pdfEditable = self.asyncImportPdf.data {
                self.trackFullActionCompleted()
                self.uploadPdf(pdfEditable: pdfEditable)
            }
        }
    }
    @Published var asyncUploadPdf: AsyncOperation<(), SharedLocalizedError> = AsyncOperation(status: .empty) {
        didSet {
            if self.asyncUploadPdf.success {
                self.chatPdfShow = true
            } else {
                self.chatPdfShow = false
            }
        }
    }
    
    @Published var chatPdfShow: Bool = false
    
    @Injected(\.store) private var store
    @Injected(\.analyticsManager) private var analyticsManager
    
    private var currentAnalyticsImportOption: ImportOption? = nil
    private var currentAnalyticsFileExtension: String? = nil
    
    private var lockedPdfEditable: PdfEditable? = nil
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.chatPdfSelection))
    }
    
    func getPdfButtonPressed() {
        self.importOptionGroup = .fileAndScan
    }
    
    @MainActor
    func handleImportOption(importOption: ImportOption) {
        switch importOption {
        case .camera:
            // TODO: Improve this by defining context-specific ImportOption types
            assertionFailure("Unexpected import option")
            break
        case .gallery:
            // TODO: Improve this by defining context-specific ImportOption types
            assertionFailure("Unexpected import option")
            break
        case .scan: self.scanPdf()
        case .file(let fileSource):
            switch fileSource {
            case .google: self.openFilePicker(fileSource: .google)
            case .dropbox: self.openFilePicker(fileSource: .dropbox)
            case .icloud: self.openFilePicker(fileSource: .icloud)
            case .files: self.openFilePicker(fileSource: .files)
            }
        }
    }
    
    @MainActor
    func openFilePicker(fileSource: FileSource) {
        self.trackFullActionChosen(importOption: .file(fileSource: fileSource))
        self.importOptionGroup = nil
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.importFileOption = .allDocs
        }
    }
    
    @MainActor
    func scanPdf() {
        self.importOptionGroup = nil
        // In this case ImportOption.scan is not actually been selected by the user,
        // but is provided for coherence
        self.trackFullActionChosen(importOption: .scan)
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.showScanner()
        }
    }
    
    @MainActor
    func convertScan(scannerResult: ScannerResult) {
        self.scannerShow = false
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            PdfScanUtility.convertScan(scannerResult: scannerResult, asyncOperation: self.asyncSubject(\.asyncImportPdf))
        }
    }
    
    @MainActor
    func processPickedFileUrl(_ fileUrl: URL) {
        self.importFileOption = nil
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.convertFileByUrl(fileUrl: fileUrl)
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
            self.asyncImportPdf = PDFUtility.decryptFile(pdfEditable: pdfEditable)
        }
    }
    
    @MainActor
    func importLockedPdf(password: String) {
        guard let pdfEditable = self.lockedPdfEditable else {
            assertionFailure("Missing expected locked pdf")
            return
        }
        self.asyncImportPdf = PDFUtility.decryptFile(pdfEditable: pdfEditable, password: password)
    }
    
    @MainActor
    private func convertFileByUrl(fileUrl: URL) {
        let fileUtType = UTType(filenameExtension: fileUrl.pathExtension)
        if fileUtType?.conforms(to: .pdf) ?? false {
            self.importPdf(pdfUrl: fileUrl)
        } else {
            self.asyncImportPdf = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
            Processor.generatePDF(from: fileUrl, options: [:]) { data, error in
                if let error = error {
                    debugPrint(for: self, message: "Error converting word file. Error: \(error)")
                    self.asyncImportPdf = AsyncOperation(status: .error(.unknownError))
                } else if let data = data, let pdfEditable = PdfEditable(data: data) {
                    self.currentAnalyticsFileExtension = fileUrl.pathExtension
                    self.asyncImportPdf = AsyncOperation(status: .data(pdfEditable))
                } else {
                    self.asyncImportPdf = AsyncOperation(status: .error(.unknownError))
                }
            }
        }
    }
    
    @MainActor
    private func showScanner() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            self.scannerShow = true
        default:
            self.cameraPermissionDeniedShow = true
        }
    }
    
    private func uploadPdf(pdfEditable: PdfEditable) {
        print("TODO: Upload Pdf")
        self.asyncUploadPdf = AsyncOperation(status: .data(()))
    }
    
    private func trackFullActionChosen(importOption: ImportOption?) {
        self.currentAnalyticsImportOption = importOption
        self.analyticsManager.track(event: .chatPdfSelectionFullActionChosen(importOption: importOption))
    }
    
    private func trackFullActionCompleted() {
        self.analyticsManager.track(event: .chatPdfSelectionFullActionCompleted(importOption: currentAnalyticsImportOption,
                                                                                fileExtension: self.currentAnalyticsFileExtension))
        self.currentAnalyticsImportOption = nil
        self.currentAnalyticsFileExtension = nil
    }
}
