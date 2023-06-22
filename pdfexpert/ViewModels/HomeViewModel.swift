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

enum SourceType: Hashable, Identifiable {
    
    var id: Self { return self }
    
    case imageFile
    case pdf
    case convertFile
    case formFill
    case sign
    case formWidget
}

enum PickerType: Hashable, Identifiable {
    
    var id: Self { return self }
    
    case image
    case pdf
    case convert
    case formFill
    case sign
}

enum FileSource {
    case google, dropbox, icloud, files
}

public class HomeViewModel : ObservableObject {
    
    @Published var pickerType: PickerType? = nil
    @Published var selectedSourceType: SourceType? = nil {
        didSet {
            if let selectedSourceType = selectedSourceType {
                self.trackFileSourceViewed(homeOption: selectedSourceType.analyticsHomeOption)
            }
        }
    }
    
    @Published var fileImagePickerShow: Bool = false
    @Published var filePickerShow: Bool = false
    @Published var pdfFilePickerShow: Bool = false
    @Published var pdfPasswordInputShow: Bool = false
    
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
    @Published var cameraPermissionDeniedShow: Bool = false
    
    @Published var asyncPdf: AsyncOperation<PdfEditable, PdfEditableError> = AsyncOperation(status: .empty) {
        didSet {
            if self.asyncPdf.success {
                self.trackPdfConversionCompletedEvent()
                self.pdfFlowShow = true
            } else {
                self.pdfFlowShow = false
            }
        }
    }
    
    @Published var pdfFlowShow: Bool = false
    
    @Injected(\.store) private var store
    @Injected(\.analyticsManager) private var analyticsManager
    
    var urlToImageToConvert: URL?
    var urlToFileToConvert: URL?
    var imageToConvert: UIImage?
    var scannerResult: ScannerResult?
    
    var currentAnalyticsPdfInputType: AnalyticsPdfInputType? = nil
    var currentAnalyticsFileSourceType: FileSource? = nil
    var currentAnalyticsInputFileExtension: String? = nil
    var editStartAction: PdfEditStartAction? = nil
    
    private var lockedPdfEditable: PdfEditable? = nil
    
    @MainActor
    func onAppear() {
        self.editStartAction = nil
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
    
    func openConvertFileFlow() {
        self.trackHomeOptionChosen(homeOption: .convertFile)
        self.selectedSourceType = .convertFile
    }
    
    func openImagePickerFlow() {
        self.trackHomeOptionChosen(homeOption: .convertImage)
        self.pickerType = .image
    }
    
    func openPdfFileFlow() {
        self.trackHomeOptionChosen(homeOption: .pdf)
        self.pickerType = .pdf
    }
    
    func openFillFormFlow() {
        self.trackHomeOptionChosen(homeOption: .fillForm)
        self.pickerType = .formFill
    }
    
    func openSignFlow() {
        self.trackHomeOptionChosen(homeOption: .signature)
        self.pickerType = .sign
    }
    
    func openFillWidgetFlow() {
        self.trackHomeOptionChosen(homeOption: .fillWidget)
        self.selectedSourceType = .formWidget
    }
    
    @MainActor
    func openFilePicker(fileSource: FileSource, sourceType: SourceType) {
        self.trackPdfConversionChosenEvent(inputType: sourceType.analyticsPdfInputType, fileSource: fileSource)
        self.selectedSourceType = nil
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            switch sourceType {
            case .imageFile: self.fileImagePickerShow = true
            case .convertFile: self.filePickerShow = true
            case .pdf: self.pdfFilePickerShow = true
            case .formFill:
                self.editStartAction = .openFillForm
                self.filePickerShow = true
            case .sign:
                self.editStartAction = .openSignature
                self.filePickerShow = true
            case .formWidget:
                self.editStartAction = .openFillWidget
                self.pdfFilePickerShow = true
            }
        }
    }
    
    @MainActor
    func openFileSourcePicker(sourceType: SourceType) {
        self.pickerType = nil
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.selectedSourceType = sourceType
        }
    }
    
    @MainActor
    func openCamera() {
        self.pickerType = nil
        self.trackPdfConversionChosenEvent(inputType: .camera, fileSource: nil)
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.cameraShow = true
        }
    }
    
    @MainActor
    func openGallery() {
        self.pickerType = nil
        self.trackPdfConversionChosenEvent(inputType: .gallery, fileSource: nil)
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.imagePickerShow = true
        }
    }
    
    @MainActor
    func scanPdf(startAction: PdfEditStartAction?, directlyFromScan: Bool) {
        self.pickerType = nil
        self.editStartAction = startAction
        if directlyFromScan {
            self.trackHomeOptionChosen(homeOption: .scan)
        }
        let inputType: AnalyticsPdfInputType = {
            switch startAction {
            case .none: return directlyFromScan ? .scan : .scanPdf
            case .openFillForm: return .scanFillForm
            case .openSignature: return .scanSign
            case .openFillWidget:
                assertionFailure("Widgets cannot exist on scanned files (as long as OCR is not implemented)")
                return .scan
            }
        }()
        self.trackPdfConversionChosenEvent(inputType: inputType, fileSource: nil)
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.showScanner()
        }
    }
    
    @MainActor
    func convert() {
        if let urlToImageToConvert = self.urlToImageToConvert {
            self.urlToImageToConvert = nil
            self.convertFileImageByURL(fileImageUrl: urlToImageToConvert)
        } else if let urlToFileToConvert = self.urlToFileToConvert {
            self.urlToFileToConvert = nil
            self.convertFileByUrl(fileUrl: urlToFileToConvert)
        } else if let imageToConvert = self.imageToConvert {
            self.imageToConvert = nil
            self.convertUiImageToPdf(uiImage: imageToConvert)
        } else if let scannerResult = self.scannerResult {
            self.scannerResult = nil
            PdfScanUtility.convertScan(scannerResult: scannerResult, asyncOperation: self.asyncSubject(\.asyncPdf))
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
            self.asyncPdf = PDFUtility.decryptFile(pdfEditable: pdfEditable)
        }
    }
    
    @MainActor
    func importLockedPdf(password: String) {
        guard let pdfEditable = self.lockedPdfEditable else {
            assertionFailure("Missing expected locked pdf")
            return
        }
        self.asyncPdf = PDFUtility.decryptFile(pdfEditable: pdfEditable, password: password)
    }
    
    @MainActor
    private func convertFileImageByURL(fileImageUrl: URL) {
        do {
            let imageData = try Data(contentsOf: fileImageUrl)
            guard let uiImage = UIImage(data: imageData) else {
                self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
                return
            }
            self.currentAnalyticsInputFileExtension = fileImageUrl.pathExtension
            self.convertUiImageToPdf(uiImage: uiImage)
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
                } else if let data = data, let pdfEditable = PdfEditable(data: data) {
                    self.currentAnalyticsInputFileExtension = fileUrl.pathExtension
                    self.asyncPdf = AsyncOperation(status: .data(pdfEditable))
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
                    self.convertUiImageToPdf(uiImage: image.uiImage)
                case .success(nil):
                    self.asyncImageLoading = AsyncOperation(status: .empty)
                case .failure(let error):
                    let convertedError = ImportImageError.convertError(fromError: error)
                    self.asyncImageLoading = AsyncOperation(status: .error(convertedError))
                }
            }
        }
    }
    
    private func convertUiImageToPdf(uiImage: UIImage) {
        let pdfDocument = PDFUtility.convertUiImageToPdf(uiImage: uiImage)
        self.asyncPdf = AsyncOperation(status: .data(PdfEditable(pdfDocument: pdfDocument)))
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
        
        guard var pdfEditable = PdfEditable(data: pdfData) else {
            self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfCannotDecode))
            resetSharedStorage()
            return
        }
        
        if pdfEditable.pdfDocument.isEncrypted {
            let password = SharedStorage.pdfDataShareExtensionPassword ?? ""
            
            guard pdfEditable.pdfDocument.unlock(withPassword: password) else {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfInvalidPasswordForLockedFile))
                resetSharedStorage()
                return
            }
            
            guard let pdfEncryptedData = pdfEditable.pdfDocument.dataRepresentation() else {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfMissingDataForUnlockedFile))
                resetSharedStorage()
                return
            }
            guard let pdfDecryptedData = try? PDFUtility.removePassword(data: pdfEncryptedData, existingPDFPassword: password) else {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfDecryptionFailed))
                resetSharedStorage()
                return
            }
            guard let pdfDecryptedEditable = PdfEditable(data: pdfDecryptedData, password: password) else {
                self.analyticsManager.track(event: .reportNonFatalError(.shareExtensionPdfCannotDecodeDecryptedData))
                resetSharedStorage()
                return
            }
            pdfEditable = pdfDecryptedEditable
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
        
        self.analyticsManager.track(event: .conversionToPdfCompleted(pdfInputType: .appExtension, fileSource: nil, fileExtension: "pdf"))
        self.asyncPdf = AsyncOperation(status: .data(pdfEditable))
    }
    
    private func trackHomeOptionChosen(homeOption: AnalyticsHomeOption) {
        self.analyticsManager.track(event: .homeOptionChosen(homeOption: homeOption))
    }
    
    private func trackFileSourceViewed(homeOption: AnalyticsHomeOption) {
        self.analyticsManager.track(event: .fileSourceViewed(homeOption: homeOption))
    }
    
    private func trackPdfConversionChosenEvent(inputType: AnalyticsPdfInputType, fileSource: FileSource?) {
        self.currentAnalyticsPdfInputType = inputType
        self.currentAnalyticsFileSourceType = fileSource
        self.analyticsManager.track(event: .conversionToPdfChosen(pdfInputType: inputType, fileSource: fileSource))
    }
    
    private func trackPdfConversionCompletedEvent() {
        if let currentAnalyticsPdfInputType = self.currentAnalyticsPdfInputType {
            self.analyticsManager.track(event: .conversionToPdfCompleted(pdfInputType: currentAnalyticsPdfInputType,
                                                                         fileSource: self.currentAnalyticsFileSourceType,
                                                                         fileExtension: self.currentAnalyticsInputFileExtension))
            self.currentAnalyticsPdfInputType = nil
            self.currentAnalyticsFileSourceType = nil
            self.currentAnalyticsInputFileExtension = nil
        }
    }
}

extension SourceType {
    var analyticsPdfInputType: AnalyticsPdfInputType {
        switch self {
        case .imageFile: return .fileImage
        case .pdf: return .filePdf
        case .convertFile: return .file
        case .formFill: return .fileFillForm
        case .sign: return .fileSign
        case .formWidget: return .fileFillWidget
        }
    }
    
    var analyticsHomeOption: AnalyticsHomeOption {
        switch self {
        case .imageFile: return .convertImage
        case .pdf: return .pdf
        case .convertFile: return .convertFile
        case .formFill: return .fillForm
        case .sign: return .signature
        case .formWidget: return .fillWidget
        }
    }
}
