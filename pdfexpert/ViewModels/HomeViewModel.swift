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

extension Container {
    var homeViewModel: Factory<HomeViewModel> {
        self { HomeViewModel() }
    }
}

enum HomeAction: Hashable, Identifiable {
    
    var id: Self { return self }
    
    case appExtension
    
    case imageToPdf
    case wordToPdf
    case excelToPdf
    case powerpointToPdf
    case scan
    
    case merge
    case split
    
    case sign
    case formFill
    case addText
    case createPdf
    
    case importPdf
    
    case readPdf
    
    case removePassword
    case addPassword
    
    var importFileOption: ImportFileOption? {
        switch self {
        case .appExtension: return nil
        case .imageToPdf: return .image
        case .wordToPdf: return .word
        case .excelToPdf: return .excel
        case .powerpointToPdf: return .powerpoint
        case .scan: return nil
        case .merge: return .pdf
        case .split: return .pdf
        case .sign: return .allDocs
        case .formFill: return .pdf
        case .addText: return .allDocs
        case .createPdf: return nil
        case .importPdf: return .pdf
        case .readPdf: return .pdf
        case .removePassword: return .pdf
        case .addPassword: return .pdf
        }
    }
    
    var editStartAction: PdfEditStartAction? {
        switch self {
        case .appExtension: return nil
        case .imageToPdf: return nil
        case .wordToPdf: return nil
        case .excelToPdf: return nil
        case .powerpointToPdf: return nil
        case .scan: return nil
        case .merge: return nil
        case .split: return nil
        case .sign: return .openSignature
        case .formFill: return .openFillWidget
        case .addText: return .openFillForm
        case .createPdf: return nil
        case .importPdf: return nil
        case .readPdf: return nil
        case .removePassword: return nil
        case .addPassword: return nil
        }
    }
    
    var homePostImportAction: HomePostImportAction? {
        switch self {
        case .appExtension: return nil
        case .imageToPdf: return nil
        case .wordToPdf: return nil
        case .excelToPdf: return nil
        case .powerpointToPdf: return nil
        case .scan: return nil
        case .merge: return nil
        case .split: return nil
        case .sign: return nil
        case .formFill: return nil
        case .addText: return nil
        case .createPdf: return nil
        case .importPdf: return nil
        case .readPdf: return nil
        case .removePassword: return .removePassword
        case .addPassword: return .addPassword
        }
    }
}

enum ImportFileOption: Hashable, Identifiable {
    
    var id: Self { return self }
    
    case image
    case word
    case excel
    case powerpoint
    case pdf
    case allDocs
}

enum FileSource: Hashable, Identifiable {
    var id: Self { return self }
    case google, dropbox, icloud, files
}

enum HomePostImportAction: Hashable, Identifiable {
    var id: Self { return self }
    case addPassword, removePassword
}

public class HomeViewModel : ObservableObject {
    
    @Published var importOptionGroup: ImportOptionGroup? = nil
    @Published var importFileOption: ImportFileOption? = nil
    
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
    
    @Published var asyncImageLoading: AsyncOperation<(), SharedUnderlyingError> = AsyncOperation(status: .empty)
    
    @Published var cameraShow: Bool = false
    @Published var scannerShow: Bool = false
    @Published var cameraPermissionDeniedShow: Bool = false
    @Published var addPasswordShow: Bool = false
    
    @Published var asyncPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let pdf = self.asyncPdf.data {
                self.trackFullActionCompleted()
                if let homePostImportAction = self.action?.homePostImportAction {
                    self.performHomePostImportAction(homePostImportAction)
                } else {
                    self.mainCoordinator.showPdfEditFlow(pdf: pdf, startAction: self.editStartAction, isNewPdf: true)
                }
            }
        }
    }
    
    @Published var pdfSaved: Pdf? = nil
    @Published var addPasswordCompletedShow: Bool = false
    @Published var removePasswordCompletedShow: Bool = false
    @Published var addPasswordError: AddPasswordError? = nil
    @Published var removePasswordError: RemovePasswordError? = nil
    
    @Injected(\.store) private var store
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.repository) private var repository
    @Injected(\.mainCoordinator) private var mainCoordinator
    @Injected(\.pdfShareCoordinator) var pdfShareCoordinator
    @Injected(\.pdfSplitViewModel) var pdfSplitViewModel
    @Injected(\.pdfReadViewModel) var pdfReadViewModel
    
    lazy var pdfUnlockViewModel: PdfUnlockViewModel = {
        Container.shared.pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfSingleOutput: self.asyncSubject(\.asyncPdf)))
    }()
    
    lazy var pdfMergeViewModel: PdfMergeViewModel = Container.shared.pdfMergeViewModel(PdfMergeViewModel.Params(asyncPdf: self.asyncSubject(\.asyncPdf)))
    
    var editStartAction: PdfEditStartAction? { self.action?.editStartAction }
    
    private var action: HomeAction? = nil
    private var currentAnalyticsImportOption: ImportOption? = nil
    private var currentAnalyticsFileExtension: String? = nil
    
    @MainActor
    func onAppear() {
        self.action = nil
        Task {
            try await self.store.refreshAll()
        }
        self.analyticsManager.track(event: .reportScreen(.home))
    }
    
    @MainActor
    func onDidBecomeActive() {
        Task {
            try await self.checkShareExtensionPdf()
        }
    }
    
    @MainActor
    func performHomeAction(_ action: HomeAction) {
        self.action = action
        self.trackActionChosen(action: action)
        
        switch action {
        case .appExtension:
            assertionFailure("App Extension behaviour is not supposed to be triggered by a CTA")
            break
        case .imageToPdf:
            self.importOptionGroup = .image
        case .wordToPdf, .excelToPdf, .powerpointToPdf, .importPdf, .formFill, .removePassword, .addPassword:
            self.openFilePicker(fileSource: .files)
        case .sign, .addText:
            self.importOptionGroup = .fileAndScan
        case .createPdf:
            self.createPdf()
        case .scan:
            self.scanPdf()
        case .merge:
            self.pdfMergeViewModel.merge()
        case .readPdf:
            self.pdfReadViewModel.read(pdf: nil)
        case .split:
            self.pdfSplitViewModel.split(pdf: nil,
                                         onSplitCompleted: { [weak self] in
                self?.trackFullActionCompleted()
                self?.mainCoordinator.goToArchive()
            })
        }
    }
    
    @MainActor
    func handleImportOption(importOption: ImportOption) {
        switch importOption {
        case .camera: self.openCamera()
        case .gallery: self.openGallery()
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
            guard let importFileOption = self.action?.importFileOption else {
                assertionFailure("Missing expected import file option for current action")
                return
            }
            self.importFileOption = importFileOption
        }
    }
    
    @MainActor
    func openCamera() {
        self.importOptionGroup = nil
        self.trackFullActionChosen(importOption: .camera)
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.cameraShow = true
        }
    }
    
    @MainActor
    func openGallery() {
        self.importOptionGroup = nil
        self.trackFullActionChosen(importOption: .gallery)
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.imagePickerShow = true
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
    func convertImage(uiImage: UIImage) {
        self.cameraShow = false
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.convertUiImageToPdf(uiImage: uiImage, filename: nil)
        }
    }
    
    @MainActor
    func convertScan(scannerResult: ScannerResult) {
        self.scannerShow = false
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            PdfScanUtility.convertScan(scannerResult: scannerResult, asyncOperation: self.asyncSubject(\.asyncPdf))
        }
    }
    
    @MainActor
    func processPickedFileUrl(_ fileUrl: URL?) {
        guard let fileUrl else {
            assertionFailure("Missing expected url")
            self.asyncPdf = AsyncOperation(status: .error(.unknownError))
            return
        }
        
        self.importFileOption = nil
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            switch self.action {
            case .imageToPdf:
                self.convertFileImageByURL(fileImageUrl: fileUrl)
            case .wordToPdf, .excelToPdf, .powerpointToPdf, .sign, .formFill, .addText, .createPdf:
                self.convertFileByUrl(fileUrl: fileUrl)
            case .importPdf, .removePassword, .addPassword:
                self.importPdf(pdfUrl: fileUrl)
            case .scan, .appExtension, .none, .merge, .split, .readPdf:
                assertionFailure("Selected file url is not handled for the current action")
            }
        }
    }
    
    @MainActor
    func importPdf(pdfUrl: URL) {
        guard let pdf = Pdf(pdfUrl: pdfUrl) else {
            assertionFailure("Missing expected file for give url")
            return
        }
        
        self.currentAnalyticsFileExtension = pdfUrl.pathExtension
        if pdf.pdfDocument.isLocked, self.action?.homePostImportAction == .addPassword {
            self.addPasswordError = .pdfHasPassword
        } else if !pdf.pdfDocument.isLocked, self.action?.homePostImportAction == .removePassword {
            self.removePasswordError = .pdfNoPassword
        } else {
            self.pdfUnlockViewModel.unlockPdf(pdf: pdf)
        }
    }
    
    func setPassword(_ password: String) {
        self.internalSetPassword(password)
        debugPrint(for: self, message: "New password: \(password)")
        self.analyticsManager.track(event: .passwordAdded)
    }
    
    func goToArchive() {
        self.mainCoordinator.goToArchive()
        self.pdfSaved = nil
    }
    
    func share() {
        guard let pdfSaved else {
            assertionFailure("Missing expected pdfSaved entity")
            return
        }
        self.pdfShareCoordinator.share(pdf: pdfSaved, applyPostProcess: false, onComplete: { [weak self] in
            self?.mainCoordinator.startReview()
        })
        self.pdfSaved = nil
    }
    
    @MainActor
    private func convertFileImageByURL(fileImageUrl: URL) {
        do {
            let imageData = try Data(contentsOf: fileImageUrl)
            guard let uiImage = UIImage(data: imageData) else {
                self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
                return
            }
            self.currentAnalyticsFileExtension = fileImageUrl.pathExtension
            self.convertUiImageToPdf(uiImage: uiImage, filename: fileImageUrl.filename)
        } catch {
            debugPrint(for: self, message: "Error retrieving file. Error: \(error)")
            self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
        }
    }
    
    @MainActor
    private func convertFileByUrl(fileUrl: URL) {
        let fileUtType = UTType(filenameExtension: fileUrl.pathExtension)
        if fileUtType?.conforms(to: .pdf) ?? false {
            self.importPdf(pdfUrl: fileUrl)
        } else {
            self.asyncPdf = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
            Processor.generatePDF(from: fileUrl, options: [:]) { data, error in
                if let error = error {
                    debugPrint(for: self, message: "Error converting word file. Error: \(error)")
                    self.asyncPdf = AsyncOperation(status: .error(.unknownError))
                } else if let data = data, var pdf = Pdf(data: data) {
                    self.currentAnalyticsFileExtension = fileUrl.pathExtension
                    pdf.updateFilename(fileUrl.filename)
                    self.asyncPdf = AsyncOperation(status: .data(pdf))
                } else {
                    self.asyncPdf = AsyncOperation(status: .error(.unknownError))
                }
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
                    self.convertUiImageToPdf(uiImage: image.uiImage, filename: nil)
                case .success(nil):
                    self.asyncImageLoading = AsyncOperation(status: .empty)
                case .failure(let error):
                    let convertedError = SharedUnderlyingError.convertError(fromError: error)
                    self.asyncImageLoading = AsyncOperation(status: .error(convertedError))
                }
            }
        }
    }
    
    private func convertUiImageToPdf(uiImage: UIImage, filename: String?) {
        let pdfDocument = PDFUtility.convertUiImageToPdf(uiImage: uiImage)
        var pdf = Pdf(pdfDocument: pdfDocument)
        if let filename {
            pdf.updateFilename(filename)
        }
        self.asyncPdf = AsyncOperation(status: .data(pdf))
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
    private func checkShareExtensionPdf() async throws {
        let pdfDataExpected = SharedStorage.pdfDataShareExtensionExistanceFlag
        let pdfData = SharedStorage.pdfDataShareExtension
        
        let resetSharedStorage = {
            SharedStorage.pdfDataShareExtension = nil
            SharedStorage.pdfDataShareExtensionExistanceFlag = false
            SharedStorage.pdfDataShareExtensionPassword = nil
        }
        
        if let pdfData = pdfData {
            let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(pdfData.count), countStyle: .file)
            debugPrint("Share Extension - Loaded pdf data with size: \(fileSizeWithUnit)")
        }
        
        guard pdfDataExpected, let pdfData = pdfData else {
            if pdfDataExpected {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfMissingRawData))
                resetSharedStorage()
            } else if pdfData != nil {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfExistingUnexpectedRawData))
                resetSharedStorage()
            }
            return
        }
        
        guard var pdf = Pdf(data: pdfData) else {
            self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfCannotDecode))
            resetSharedStorage()
            return
        }
        
        if pdf.pdfDocument.isEncrypted {
            let password = SharedStorage.pdfDataShareExtensionPassword ?? ""
            
            guard pdf.pdfDocument.unlock(withPassword: password) else {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfInvalidPasswordForLockedFile))
                resetSharedStorage()
                return
            }
            
            guard let pdfEncryptedData = pdf.pdfDocument.dataRepresentation() else {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfMissingDataForUnlockedFile))
                resetSharedStorage()
                return
            }
            guard let pdfDecryptedData = try? PDFUtility.removePassword(data: pdfEncryptedData, existingPDFPassword: password) else {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfDecryptionFailed))
                resetSharedStorage()
                return
            }
            guard var pdfDecrypted = Pdf(data: pdfDecryptedData) else {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfCannotDecodeDecryptedData))
                resetSharedStorage()
                return
            }
            pdfDecrypted.updatePassword(password)
            pdf = pdfDecrypted
        }
        resetSharedStorage()
        // TODO: Ask the user whether to discard the current pdf or not
        if self.asyncPdf.data != nil {
            self.asyncPdf = AsyncOperation(status: .empty)
            // This is a workaround to force swiftui to update its state and dismiss
            // the current modal for the pdf edit flow, so that the new one can be
            // shown in its place.
            try await Task.sleep(until: .now + .seconds(0.5), clock: .continuous)
        }
        
        self.analyticsManager.track(event: .homeFullActionCompleted(homeAction: .appExtension, importOption: nil, fileExtension: "pdf"))
        self.asyncPdf = AsyncOperation(status: .data(pdf))
    }
    
    private func createPdf() {
        self.trackFullActionChosen(importOption: nil)
        self.asyncPdf = AsyncOperation(status: .data(Pdf()))
    }
    
    private func performHomePostImportAction(_ action: HomePostImportAction) {
        switch action {
        case .addPassword:
            self.addPasswordShow = true
        case .removePassword:
            self.internalSetPassword(nil)
            debugPrint(for: self, message: "Password removed")
            self.analyticsManager.track(event: .passwordRemoved)
        }
    }
    
    private func internalSetPassword(_ password: String?) {
        guard var pdf = self.asyncPdf.data else {
            assertionFailure("Missing expected pdf ")
            self.asyncPdf = AsyncOperation(status: .error(.unknownError))
            return
        }
        do {
            pdf.updatePassword(password)
            self.pdfSaved = try self.repository.savePdf(pdf: pdf)
            if password != nil {
                self.addPasswordCompletedShow = true
            } else {
                self.removePasswordCompletedShow = true
            }
            self.asyncPdf = AsyncOperation(status: .empty)
        } catch {
            debugPrint(for: self, message: "Pdf save failed with error: \(error)")
            self.asyncPdf = AsyncOperation(status: .error(.unknownError))
        }
    }
    
    private func trackActionChosen(action: HomeAction) {
        self.analyticsManager.track(event: .homeActionChosen(homeAction: action))
    }
    
    private func trackFullActionChosen(importOption: ImportOption?) {
        if let action = self.action {
            self.currentAnalyticsImportOption = importOption
            self.analyticsManager.track(event: .homeFullActionChosen(homeAction: action, importOption: importOption))
        }
    }
    
    private func trackFullActionCompleted() {
        if let action = self.action {
            self.analyticsManager.track(event: .homeFullActionCompleted(homeAction: action,
                                                                        importOption: self.currentAnalyticsImportOption,
                                                                        fileExtension: self.currentAnalyticsFileExtension))
        }
        self.currentAnalyticsImportOption = nil
        self.currentAnalyticsFileExtension = nil
    }
}
