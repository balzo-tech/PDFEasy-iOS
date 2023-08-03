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
import Combine

extension Container {
    var chatPdfSelectionViewModel: Factory<ChatPdfSelectionViewModel> {
        self { ChatPdfSelectionViewModel() }
    }
}

class ChatPdfSelectionViewModel: ObservableObject {
    
    @Published var importOptionGroup: ImportOptionGroup? = nil
    @Published var importFileOption: ImportFileOption? = nil
    
    @Published var scannerShow: Bool = false
    @Published var cameraPermissionDeniedShow: Bool = false
    
    @MainActor @Published var asyncImportPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let pdf = self.asyncImportPdf.data {
                self.trackFullActionCompleted()
                self.uploadPdf(pdf: pdf)
            }
        }
    }
    
    @Published var asyncChatPdfSetup: AsyncOperation<ChatPdfInitParams, ChatPdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let chatPdfInitParams = self.asyncChatPdfSetup.data {
                self.chatPdfInitParams = chatPdfInitParams
            } else {
                self.chatPdfInitParams = nil
            }
        }
    }
    
    @Published var chatPdfInitParams: ChatPdfInitParams? = nil
    
    @Published var monetizationShow: Bool = false
    
    @Injected(\.store) private var store
    @Injected(\.chatPdfManager) private var chatPdfManager
    @Injected(\.analyticsManager) private var analyticsManager
    
    lazy var pdfUnlockViewModel: PdfUnlockViewModel = {
        Container.shared.pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfSingleOutput: self.asyncSubject(\.asyncImportPdf)))
    }()
    
    private var currentAnalyticsImportOption: ImportOption? = nil
    private var currentAnalyticsFileExtension: String? = nil
    
    private var cancelBag = Set<AnyCancellable>()
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.chatPdfSelection))
    }
    
    func getPdfButtonPressed() {
        self.trackPdfSelection()
        if self.store.isPremium.value {
            self.importOptionGroup = .fileAndScan
        } else {
            self.monetizationShow = true
        }
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
    func processPickedFileUrl(_ fileUrl: URL?) {
        guard let fileUrl else {
            assertionFailure("Missing expected url")
            self.asyncImportPdf = AsyncOperation(status: .error(.unknownError))
            return
        }
        
        self.importFileOption = nil
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.convertFileByUrl(fileUrl: fileUrl)
        }
    }
    
    @MainActor
    func importPdf(pdfUrl: URL) {
        guard let pdf = Pdf(pdfUrl: pdfUrl) else {
            assertionFailure("Missing expected file for give url")
            return
        }
        
        self.currentAnalyticsFileExtension = pdfUrl.pathExtension
        self.pdfUnlockViewModel.unlock(pdf: pdf)
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
                } else if let data = data, let pdf = Pdf(data: data) {
                    self.currentAnalyticsFileExtension = fileUrl.pathExtension
                    self.asyncImportPdf = AsyncOperation(status: .data(pdf))
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
    
    @MainActor
    private func uploadPdf(pdf: Pdf) {
        guard let pdfData = pdf.rawData else {
            assertionFailure("Missing expected pdf data")
            self.asyncChatPdfSetup = AsyncOperation(status: .error(.unknownError))
            return
        }
        
        self.asyncChatPdfSetup = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        guard pdfData.count <= K.ChatPdf.MaxBytes else {
            self.asyncChatPdfSetup = AsyncOperation(status: .error(.pdfTooLarge))
            return
        }
        
        guard pdf.pdfDocument.pageCount <= K.ChatPdf.MaxPages else {
            self.asyncChatPdfSetup = AsyncOperation(status: .error(.pdfTooManyPages))
            return
        }
        
        self.chatPdfManager.sendPdf(pdf: pdfData)
            .flatMap { chatPdfRef in
                self.chatPdfManager.generateText(ref: chatPdfRef, prompt: K.ChatPdf.IntroductoryMessageRequest)
                    .map { ChatPdfInitParams(chatPdfRef: chatPdfRef, introductoryMessage: $0) }
            }
            .sinkToAsyncStatus { [weak self] status in
                self?.asyncChatPdfSetup = AsyncOperation(status: status)
            }.store(in: &self.cancelBag)
    }
    
    private func trackPdfSelection() {
        self.analyticsManager.track(event: .chatPdfSelectionActionChosen)
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
