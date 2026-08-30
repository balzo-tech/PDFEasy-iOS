//
//  ChatPdfSelectionViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import Foundation
import Factory
import PhotosUI
import Combine

extension Container {
    var chatPdfSelectionViewModel: Factory<ChatPdfSelectionViewModel> {
        self { ChatPdfSelectionViewModel() }
    }
}

class ChatPdfSelectionViewModel: ObservableObject, SignedContainerImporting {
    
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

    // Office / iWork documents are converted on-device, with an optional online
    // fallback (see OfficeImportCoordinator). Replaces the former PSPDFKit call.
    /// Set when a signed container has been opened: drives the sheet that shows who
    /// signed it, before the document inside is imported.
    @Published var signedDocument: SignedDocumentPresentation? = nil

    lazy var officeImportCoordinator: OfficeImportCoordinator = {
        Container.shared.officeImportCoordinator(OfficeImportCoordinator.Params(asyncPdf: self.asyncSubject(\.asyncImportPdf)))
    }()
    
    private var currentAnalyticsImportOption: ImportOption? = nil
    private var currentAnalyticsFileExtension: String? = nil
    
    private var cancelBag = Set<AnyCancellable>()
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.chatPdfSelection))
    }

    func getPdfButtonPressed() {
        #if DEBUG
        // Starts the conversation on the bundled test document instead of
        // opening the import sheet, which is the only way to reach the chat from
        // a UI test: the file picker cannot be driven, and the scanner hands over
        // photographed pages, which carry no extractable text — the chat refuses
        // those, and rightly so. The bundled document is used rather than the
        // first one in the archive because on a real phone the archive is full
        // of scans.
        //
        // It is the lease, not `test.pdf`: the answer has to quote something,
        // and an answer about Lorem ipsum is not a screenshot anyone can read.
        //   xcrun simctl spawn booted defaults write <bundle-id> debugChatWithArchive -bool YES
        if UserDefaults.standard.bool(forKey: "debugChatWithArchive"),
           let pdf = K.Test.DebugContractPdf {
            Task { @MainActor in self.uploadPdf(pdf: pdf) }
            return
        }
        #endif
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
    func convertScan(pages: [ScannedPage]) {
        self.scannerShow = false
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            PdfScanUtility.convertScan(pages: pages, asyncOperation: self.asyncSubject(\.asyncImportPdf))
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
        self.pdfUnlockViewModel.unlockPdf(pdf: pdf)
    }
    
    /// A document dropped onto the well from another app. It goes through the
    /// same unlock step a picked file does, so a protected PDF still asks for
    /// its password before anything is read out of it.
    @MainActor
    func importDroppedPdf(_ pdf: Pdf) {
        self.pdfUnlockViewModel.unlockPdf(pdf: pdf)
    }

    @MainActor
    func onSignedContainerFailure(_ error: PdfError) {
        self.asyncImportPdf = AsyncOperation(status: .error(error))
    }

    @MainActor
    func onSignedDocumentOpen(url: URL) {
        self.signedDocument = nil
        // Deferred so the sheet finishes dismissing before the editor is presented:
        // two presentations in the same runloop turn and the second is dropped.
        DispatchQueue.main.async { self.convertFileByUrl(fileUrl: url) }
    }

    @MainActor
    func convertFileByUrl(fileUrl: URL) {
        guard let fileUrl = self.unwrappingSignedContainer(fileUrl) else { return }
        let fileUtType = UTType(filenameExtension: fileUrl.pathExtension)
        if fileUtType?.conforms(to: .pdf) ?? false {
            self.importPdf(pdfUrl: fileUrl)
        } else {
            self.currentAnalyticsFileExtension = fileUrl.pathExtension
            self.officeImportCoordinator.convert(fileUrl: fileUrl)
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

        // The PDF is no longer uploaded to a third party: `sendPdf` extracts the
        // text on-device, so the old upload size / page-count limits no longer
        // apply. Oversized text is truncated by the manager instead.
        self.chatPdfManager.sendPdf(pdf: pdfData)
            .flatMap { chatPdfRef in
                self.chatPdfManager.getSetupData(ref: chatPdfRef)
                    .map { ChatPdfInitParams(chatPdfRef: chatPdfRef, setupData: $0) }
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
