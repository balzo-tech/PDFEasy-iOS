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
import PDFKit
import AVFoundation

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
    case webToPdf
    case markdownToPdf
    case scan

    case merge
    case split
    case extractPages
    case exportPdf
    case pdfToWord
    case pdfToPowerpoint
    case pdfToExcel
    case pdfToPdfa
    case repairPdf
    case sanitizePdf

    case sign
    case formFill
    case addText
    case createPdf
    case ocr
    case rotatePdf
    case pageNumbers
    case watermark
    case removeBlankPages
    case flattenPdf
    case invertColors
    case pdfPermissions
    case redactPdf
    case compressPdf
    case comparePdf

    /// Lifting the subject out of a photograph. It lives in the tool catalog and
    /// nowhere else on purpose — see `ToolCategory.image`.
    case removeBackground
    /// The identity photo. Shares the segmentation engine with the one above and
    /// nothing else: it ends in a print, not in a document.
    case passportPhoto
    /// Turn, crop and tone a photograph. The same operations the PDF tools have
    /// always had, pointed at a picture instead of a page.
    case editImage
    /// A caption over a picture. The only tool here whose output is meant to
    /// leave the phone rather than be filed on it.
    case memeMaker
    /// Make photographs smaller, several at a time. The only tool in this family
    /// that is free, and the only one that works on a whole selection at once.
    case compressImage

    case importPdf
    /// Opening a `.p7m` on purpose, rather than stumbling on one. The import path
    /// already takes the envelope off whatever the file arrives through, but nobody
    /// looks for a feature they have no reason to believe is there.
    case openSignedDocument
    
    case readPdf
    
    case removePassword
    case addPassword
    
    /// True for the conversions that can only start from a document the user
    /// already has somewhere. Those are the ones where an empty file browser is
    /// the likely ending: a `.docx` arrives by mail or by chat and stays there,
    /// and Files never sees it.
    var startsFromStoredDocument: Bool {
        switch self {
        case .wordToPdf, .excelToPdf, .powerpointToPdf: return true
        default: return false
        }
    }

    var importFileOption: ImportFileOption? {
        switch self {
        case .appExtension: return nil
        case .imageToPdf: return .image
        case .wordToPdf: return .word
        case .excelToPdf: return .excel
        case .powerpointToPdf: return .powerpoint
        // Both tools present their own input UI instead of the file picker.
        case .webToPdf: return nil
        case .markdownToPdf: return nil
        case .scan: return nil
        case .merge: return .pdf
        case .split: return .pdf
        case .extractPages: return nil
        case .exportPdf: return nil
        case .pdfToWord: return nil
        case .pdfToPowerpoint: return nil
        case .pdfToExcel: return nil
        case .pdfToPdfa: return nil
        case .repairPdf: return nil
        case .sanitizePdf: return nil
        case .sign: return .allDocs
        case .formFill: return .pdf
        case .addText: return .allDocs
        case .createPdf: return nil
        case .ocr: return .pdf
        case .rotatePdf: return .pdf
        case .pageNumbers: return .pdf
        case .watermark: return .pdf
        case .removeBlankPages: return .pdf
        case .flattenPdf: return .pdf
        case .invertColors: return .pdf
        // These run their own import + editor, like the other archive-saving tools.
        case .pdfPermissions: return nil
        case .redactPdf: return nil
        case .compressPdf: return nil
        case .comparePdf: return nil
        case .removeBackground: return .image
        case .passportPhoto: return .image
        case .editImage: return .image
        case .memeMaker: return .image
        case .compressImage: return .image
        case .importPdf: return .pdf
        case .openSignedDocument: return .signedContainer
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
        case .webToPdf: return nil
        case .markdownToPdf: return nil
        case .scan: return nil
        case .merge: return nil
        case .split: return nil
        case .extractPages: return nil
        case .exportPdf: return nil
        case .pdfToWord: return nil
        case .pdfToPowerpoint: return nil
        case .pdfToExcel: return nil
        case .pdfToPdfa: return nil
        case .repairPdf: return nil
        case .sanitizePdf: return nil
        case .sign: return .openSignature
        case .formFill: return .openFillWidget
        case .addText: return .openFillForm
        case .createPdf: return nil
        case .ocr: return .openOcr
        case .rotatePdf: return .openRotate
        case .pageNumbers: return .openPageNumbers
        case .watermark: return .openWatermark
        case .removeBlankPages: return .openRemoveBlankPages
        case .flattenPdf: return .openFlatten
        case .invertColors: return .openInvertColors
        case .pdfPermissions: return nil
        case .redactPdf: return nil
        case .compressPdf: return nil
        case .comparePdf: return nil
        case .removeBackground: return nil
        case .passportPhoto: return nil
        case .editImage: return nil
        case .memeMaker: return nil
        case .compressImage: return nil
        case .importPdf: return nil
        case .openSignedDocument: return nil
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
        case .webToPdf: return nil
        case .markdownToPdf: return nil
        case .scan: return nil
        case .merge: return nil
        case .split: return nil
        case .extractPages: return nil
        case .exportPdf: return nil
        case .pdfToWord: return nil
        case .pdfToPowerpoint: return nil
        case .pdfToExcel: return nil
        case .pdfToPdfa: return nil
        case .repairPdf: return nil
        case .sanitizePdf: return nil
        case .sign: return nil
        case .formFill: return nil
        case .addText: return nil
        case .createPdf: return nil
        case .ocr: return nil
        case .rotatePdf: return nil
        case .pageNumbers: return nil
        case .watermark: return nil
        case .removeBlankPages: return nil
        case .flattenPdf: return nil
        case .invertColors: return nil
        case .pdfPermissions: return nil
        case .redactPdf: return nil
        case .compressPdf: return nil
        case .comparePdf: return nil
        case .removeBackground: return nil
        case .passportPhoto: return nil
        case .editImage: return nil
        case .memeMaker: return nil
        case .compressImage: return nil
        case .importPdf: return nil
        case .openSignedDocument: return nil
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
    /// Only the envelopes, for the tool that exists to open them.
    case signedContainer
}

enum FileSource: Hashable, Identifiable {
    var id: Self { return self }
    case google, dropbox, icloud, files
}

enum HomePostImportAction: Hashable, Identifiable {
    var id: Self { return self }
    case addPassword, removePassword
}

public class HomeViewModel : ObservableObject, SignedContainerImporting {
    
    @Published var importOptionGroup: ImportOptionGroup? = nil
    @Published var importFileOption: ImportFileOption? = nil
    /// Offered when the file browser closes with nothing chosen on a conversion
    /// that has to start from a document someone already has. The way in that
    /// works is the share sheet — 82 documents a month arrive that way, without
    /// ever touching this screen — and nothing was telling anybody.
    @Published var emptyPickerHintShow: Bool = false
    
    @Published var imagePickerShow: Bool = false
    /// Every photo chosen, in the order they were chosen: "Image to PDF" makes one
    /// page per picture, and picking them one at a time is not what anyone means by
    /// turning photos into a document.
    @Published var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            guard !self.imageSelections.isEmpty else {
                self.asyncImageLoading = AsyncOperation(status: .empty)
                return
            }
            self.loadImages(from: self.imageSelections)
        }
    }
    /// More than a scanner's worth of pages in one go is a mistake, not a wish, and
    /// each photo is decoded at full size on its way to a page.
    static let maxPhotoSelectionCount: Int = 50
    
    @Published var asyncImageLoading: AsyncOperation<(), SharedUnderlyingError> = AsyncOperation(status: .empty)
    
    enum ActiveSheet: Identifiable {
        case camera, scanner
        var id: Self { self }
    }

    @Published var activeSheet: ActiveSheet?
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
    @Injected(\.pdfExtractViewModel) var pdfExtractViewModel
    @Injected(\.pdfExportViewModel) var pdfExportViewModel
    @Injected(\.pdfConvertViewModel) var pdfConvertViewModel
    @Injected(\.pdfAdvancedToolViewModel) var pdfAdvancedToolViewModel
    @Injected(\.pdfPermissionsViewModel) var pdfPermissionsViewModel
    @Injected(\.pdfRedactViewModel) var pdfRedactViewModel
    @Injected(\.pdfCompressViewModel) var pdfCompressViewModel
    @Injected(\.pdfCompareViewModel) var pdfCompareViewModel
    @Injected(\.pdfReadViewModel) var pdfReadViewModel
    
    lazy var pdfUnlockViewModel: PdfUnlockViewModel = {
        Container.shared.pdfUnlockViewModel(PdfUnlockViewModel.Params(asyncUnlockedPdfSingleOutput: self.asyncSubject(\.asyncPdf)))
    }()

    // Office / iWork documents are converted on-device, with an optional online
    // fallback (see OfficeImportCoordinator). Replaces the former PSPDFKit call.
    /// Set when a signed container has been opened: drives the sheet that shows who
    /// signed it, before the document inside is imported.
    @Published var signedDocument: SignedDocumentPresentation? = nil

    lazy var officeImportCoordinator: OfficeImportCoordinator = {
        Container.shared.officeImportCoordinator(OfficeImportCoordinator.Params(asyncPdf: self.asyncSubject(\.asyncPdf)))
    }()

    // Web page / Markdown → PDF. Both write their result into `asyncPdf`, so the editor
    // opens through the same path as every other import.
    lazy var pdfWebImportViewModel: PdfWebImportViewModel = {
        Container.shared.pdfWebImportViewModel(PdfWebImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncPdf)))
    }()

    lazy var pdfMarkdownImportViewModel: PdfMarkdownImportViewModel = {
        Container.shared.pdfMarkdownImportViewModel(PdfMarkdownImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncPdf)))
    }()
    
    lazy var backgroundRemovalViewModel: BackgroundRemovalViewModel = Container.shared.backgroundRemovalViewModel()

    lazy var passportPhotoViewModel: PassportPhotoViewModel = Container.shared.passportPhotoViewModel()

    lazy var imageEditorViewModel: ImageEditorViewModel = Container.shared.imageEditorViewModel()

    lazy var memeMakerViewModel: MemeMakerViewModel = Container.shared.memeMakerViewModel()

    lazy var imageCompressViewModel: ImageCompressViewModel = Container.shared.imageCompressViewModel()

    /// The outline the camera draws over its preview, when the tool that opened
    /// it has something to say about where the subject goes.
    var cameraGuide: CameraFrameGuide? {
        guard self.action == .passportPhoto else { return nil }
        return CameraFrameGuide(spec: self.passportPhotoViewModel.spec)
    }

    /// An identity photo is a selfie. Everything else opens where it always did.
    var cameraStartingPosition: AVCaptureDevice.Position {
        self.action == .passportPhoto ? .front : .back
    }

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
        case .imageToPdf, .removeBackground, .passportPhoto, .editImage, .compressImage:
            // The same three doors as Image to PDF — camera, library, file. What
            // happens to the picture afterwards is decided in `handleImportedImage`.
            self.importOptionGroup = .image
        case .memeMaker:
            // The only tool that does not begin at the picker. A meme starts from
            // a template people already recognise, so the editor opens on the
            // gallery and owns its own camera-roll tile — presenting the picker
            // from here, underneath a full-screen cover, is the dropped
            // presentation in `swiftui-presentation-traps`.
            self.trackFullActionChosen(importOption: nil)
            self.memeMakerViewModel.start(onFinished: { [weak self] in
                self?.trackFullActionCompleted()
            })
        case .wordToPdf, .excelToPdf, .powerpointToPdf, .importPdf, .formFill, .removePassword, .addPassword,
                .rotatePdf, .pageNumbers, .watermark, .removeBlankPages, .flattenPdf, .invertColors,
                .openSignedDocument:
            self.openFilePicker(fileSource: .files)
        case .sign, .addText, .ocr:
            self.importOptionGroup = .fileAndScan
        case .createPdf:
            self.createPdf()
        case .webToPdf:
            self.pdfWebImportViewModel.start()
        case .markdownToPdf:
            self.pdfMarkdownImportViewModel.start()
        case .scan:
            // The scanner is a place in the app, not a modal this screen owns:
            // the tool tile is one of several doors onto the same tab.
            self.mainCoordinator.startScan()
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
        case .extractPages:
            self.pdfExtractViewModel.extract(pdf: nil,
                                             onExtractCompleted: { [weak self] in
                self?.trackFullActionCompleted()
                self?.mainCoordinator.goToArchive()
            })
        case .exportPdf:
            self.pdfExportViewModel.export(pdf: nil)
        case .pdfToWord:
            self.pdfConvertViewModel.convert(pdf: nil, format: .word)
        case .pdfToPowerpoint:
            self.pdfConvertViewModel.convert(pdf: nil, format: .powerpoint)
        case .pdfToExcel:
            self.pdfConvertViewModel.convert(pdf: nil, format: .csv)
        case .pdfToPdfa:
            self.pdfAdvancedToolViewModel.run(pdf: nil, tool: .pdfa) { [weak self] in
                self?.trackFullActionCompleted()
                self?.mainCoordinator.goToArchive()
            }
        case .repairPdf:
            self.pdfAdvancedToolViewModel.run(pdf: nil, tool: .repair) { [weak self] in
                self?.trackFullActionCompleted()
                self?.mainCoordinator.goToArchive()
            }
        case .sanitizePdf:
            self.pdfAdvancedToolViewModel.run(pdf: nil, tool: .sanitize) { [weak self] in
                self?.trackFullActionCompleted()
                self?.mainCoordinator.goToArchive()
            }
        case .pdfPermissions:
            self.pdfPermissionsViewModel.run(pdf: nil) { [weak self] in
                self?.trackFullActionCompleted()
                self?.mainCoordinator.goToArchive()
            }
        case .redactPdf:
            self.pdfRedactViewModel.run(pdf: nil) { [weak self] in
                self?.trackFullActionCompleted()
                self?.mainCoordinator.goToArchive()
            }
        case .compressPdf:
            self.pdfCompressViewModel.run(pdf: nil) { [weak self] in
                self?.trackFullActionCompleted()
                self?.mainCoordinator.goToArchive()
            }
        case .comparePdf:
            // Comparing writes nothing, so there is no archive to send the user to.
            self.pdfCompareViewModel.run(pdf: nil) { [weak self] in
                self?.trackFullActionCompleted()
            }
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
    
    /// The browser closed with nothing chosen. Worth its own event: `word_to_pdf`
    /// opens this picker 112 times a month and finishes 18 documents, and until
    /// now the funnel could not tell a conversion that failed from a folder that
    /// had no document in it. A `.docx` usually lives in a mail, a chat or a
    /// computer — not in Files — so this is the likely half.
    @MainActor
    func onFilePickerCancelled() {
        self.importFileOption = nil
        guard let action = self.action else { return }
        self.analyticsManager.track(event: .filePickerCancelled(homeAction: action))
        if action.startsFromStoredDocument {
            self.emptyPickerHintShow = true
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
        // Defer to the next runloop so the import sheet finishes dismissing first
        // (replaces a fixed Task.sleep delay).
        DispatchQueue.main.async {
            self.activeSheet = .camera
        }
    }
    
    @MainActor
    func openGallery() {
        self.importOptionGroup = nil
        self.trackFullActionChosen(importOption: .gallery)
        DispatchQueue.main.async {
            self.imagePickerShow = true
        }
    }
    
    @MainActor
    func scanPdf() {
        self.importOptionGroup = nil
        // In this case ImportOption.scan is not actually been selected by the user,
        // but is provided for coherence
        self.trackFullActionChosen(importOption: .scan)
        DispatchQueue.main.async {
            self.showScanner()
        }
    }
    
    @MainActor
    func convertImage(uiImage: UIImage) {
        self.activeSheet = nil
        DispatchQueue.main.async {
            self.handleImportedImage(uiImage, filename: nil)
        }
    }
    
    @MainActor
    func convertScan(pages: [ScannedPage]) {
        self.activeSheet = nil
        DispatchQueue.main.async {
            PdfScanUtility.convertScan(pages: pages, asyncOperation: self.asyncSubject(\.asyncPdf))
        }
    }
    
    @MainActor
    func processPickedFileUrl(_ fileUrl: URL?) {
        guard let fileUrl else {
            assertionFailure("Missing expected url")
            self.asyncPdf = AsyncOperation(status: .error(.unknownError))
            return
        }

        if let action = self.action {
            self.analyticsManager.track(event: .filePicked(homeAction: action,
                                                           fileExtension: fileUrl.pathExtension))
        }
        self.importFileOption = nil
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            switch self.action {
            case .imageToPdf, .removeBackground, .passportPhoto, .editImage:
                self.convertFileImageByURL(fileImageUrl: fileUrl)
            case .compressImage:
                // Not through `convertFileImageByURL`: decoding the file into a
                // `UIImage` and re-encoding it would throw away the original
                // bytes, which are the very thing this tool measures against.
                self.compressImages(fileUrls: [fileUrl])
            case .wordToPdf, .excelToPdf, .powerpointToPdf, .sign, .formFill, .addText, .createPdf:
                self.convertFileByUrl(fileUrl: fileUrl)
            case .importPdf, .removePassword, .addPassword, .ocr, .rotatePdf, .pageNumbers, .watermark,
                    .removeBlankPages, .flattenPdf, .invertColors:
                // These pickers list `.p7m` too (the type is in `ImportFileOption.pdf`),
                // and `Pdf(pdfUrl:)` cannot open an envelope: without this the file the
                // picker just offered comes back as "this is not a PDF".
                guard let fileUrl = self.unwrappingSignedContainer(fileUrl) else { return }
                self.importPdf(pdfUrl: fileUrl)
            case .openSignedDocument:
                self.openingSignedContainer(fileUrl)
            case .memeMaker, .scan, .appExtension, .none, .merge, .split, .extractPages, .exportPdf, .readPdf,
                    .pdfToWord, .pdfToPowerpoint, .pdfToExcel, .pdfToPdfa, .repairPdf, .sanitizePdf,
                    .webToPdf, .markdownToPdf, .pdfPermissions, .redactPdf, .compressPdf, .comparePdf:
                assertionFailure("Selected file url is not handled for the current action")
            }
        }
    }
    
    /// A document another app handed over — "Copy to PDF Pro" from a share sheet,
    /// or an "Open in" menu. It behaves exactly as if the file had been picked
    /// here: a PDF opens in the editor, anything else goes through the same
    /// conversion, with the same offer of the online fallback when the device
    /// cannot manage it.
    ///
    /// The action is `.appExtension` because there is nothing to do afterwards:
    /// this file arrived on its own rather than as a step of a tool, so there is
    /// no password to set and no form to fill.
    @MainActor
    func importExternalFile(url: URL) {
        self.action = .appExtension
        self.currentAnalyticsImportOption = nil
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false {
            self.convertFileImageByURL(fileImageUrl: url)
        } else {
            self.convertFileByUrl(fileUrl: url)
        }
    }

    @MainActor
    func importPdf(pdfUrl: URL) {
        guard let pdf = Pdf(pdfUrl: pdfUrl) else {
            // A file that will not open is not a programming mistake: it is a
            // truncated download, a damaged attachment, something with a .pdf
            // on the end that never was one. The assertion that used to be here
            // took the app down in debug and did nothing at all in release —
            // where opening a damaged file simply appeared to do nothing.
            self.asyncPdf = AsyncOperation(status: .error(.urlToPdfConversionError))
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
        debugPrint(for: self, message: "New password set")
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
        self.pdfShareCoordinator.share(pdf: pdfSaved, onComplete: { [weak self] in
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
            self.handleImportedImage(uiImage, filename: fileImageUrl.filename)
        } catch {
            debugPrint(for: self, message: "Error retrieving file. Error: \(error)")
            self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
        }
    }
    
    @MainActor
    func onSignedContainerFailure(_ error: PdfError) {
        self.asyncPdf = AsyncOperation(status: .error(error))
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
    
    /// One page per photo, built as the photos arrive rather than collected first:
    /// fifty pictures at the size a phone camera writes them are more bitmap than
    /// the app is allowed to hold at once, and only one is needed at a time.
    ///
    /// A photo the library cannot hand over does not take the others down with it —
    /// the document is only refused if *nothing* could be read.
    private func loadImages(from selections: [PhotosPickerItem]) {
        // The one tool here that wants the whole selection. It also wants the
        // bytes rather than a decoded picture: what it reports is how much
        // smaller the file got, and a `UIImage` no longer knows how big the file
        // was. They are written to disk as they arrive, so fifty photographs are
        // never in memory together.
        if self.action == .compressImage {
            let progress = Progress(totalUnitCount: Int64(selections.count))
            self.asyncImageLoading = AsyncOperation(status: .loading(progress))
            Task { @MainActor in
                var sources: [ImageCompressSource] = []
                for (index, selection) in selections.enumerated() {
                    guard selections == self.imageSelections else { return }
                    if let data = try? await selection.loadTransferable(type: Data.self),
                       let source = ImageCompressViewModel.makeSource(data: data,
                                                                      filename: nil,
                                                                      index: index) {
                        sources.append(source)
                    }
                    progress.completedUnitCount += 1
                }
                guard !sources.isEmpty else {
                    self.asyncImageLoading = AsyncOperation(status: .empty)
                    return
                }
                self.asyncImageLoading = AsyncOperation(status: .data(()))
                self.startImageCompression(sources: sources)
            }
            return
        }

        // Removing a background is a one-photo job: the picker allows several
        // because Image to PDF wants them, and taking the first is kinder than
        // silently cutting out fifty subjects nobody asked for.
        if self.action == .removeBackground || self.action == .passportPhoto
            || self.action == .editImage {
            guard let first = selections.first else { return }
            self.asyncImageLoading = AsyncOperation(status: .loading(Progress()))
            Task { @MainActor in
                do {
                    guard let picked = try await first.loadTransferable(type: PickedImage.self) else {
                        self.asyncImageLoading = AsyncOperation(status: .empty)
                        return
                    }
                    self.asyncImageLoading = AsyncOperation(status: .data(()))
                    self.handleImportedImage(picked.uiImage, filename: nil)
                } catch {
                    self.asyncImageLoading = AsyncOperation(
                        status: .error(SharedUnderlyingError.convertError(fromError: error))
                    )
                }
            }
            return
        }

        let progress = Progress(totalUnitCount: Int64(selections.count))
        self.asyncImageLoading = AsyncOperation(status: .loading(progress))
        Task { @MainActor in
            let pdfDocument = PDFDocument()
            var failure: Error?
            for selection in selections {
                // A second pick made while this one is still loading wins: its
                // pages would otherwise arrive in the middle of these.
                guard selections == self.imageSelections else { return }
                do {
                    if let picked = try await selection.loadTransferable(type: PickedImage.self) {
                        let upright = await self.uprightedIfDocument(picked.uiImage)
                        PDFUtility.appendImageToPdfDocument(pdfDocument: pdfDocument,
                                                            uiImage: upright)
                    }
                } catch {
                    failure = error
                }
                progress.completedUnitCount += 1
            }
            guard pdfDocument.pageCount > 0 else {
                if let failure {
                    self.asyncImageLoading = AsyncOperation(
                        status: .error(SharedUnderlyingError.convertError(fromError: failure))
                    )
                } else {
                    self.asyncImageLoading = AsyncOperation(status: .empty)
                }
                return
            }
            self.asyncImageLoading = AsyncOperation(status: .data(()))
            self.asyncPdf = AsyncOperation(status: .data(Pdf(pdfDocument: pdfDocument)))
        }
    }
    
    /// Where a picked photograph goes.
    ///
    /// Every tool that starts from an image comes through here, which is the one
    /// place that knows what the user asked for: the picker, the camera and the
    /// file browser are shared, and none of them should have to.
    @MainActor
    private func handleImportedImage(_ uiImage: UIImage, filename: String?) {
        switch self.action {
        case .removeBackground:
            self.backgroundRemovalViewModel.run(image: uiImage, onCreatePdf: { [weak self] cutOut in
                // A cut-out becomes a document through exactly the path a photo
                // takes, so it lands in the editor with everything else.
                self?.convertUiImageToPdf(uiImage: cutOut, filename: filename)
                self?.trackFullActionCompleted()
            })
        case .editImage:
            // Both of these end in a picture, and the PDF is only one of the
            // three ways out they offer — so the document is built on request,
            // not on the way through, and the home funnel is told the job is
            // done from `onFinished` rather than from the PDF branch. Counting
            // it there would have marked the two tools least likely to end in a
            // document as the two that never finish.
            self.imageEditorViewModel.run(image: uiImage,
                                          onCreatePdf: { [weak self] edited in
                self?.convertUiImageToPdf(uiImage: edited, filename: filename)
            }, onFinished: { [weak self] in
                self?.trackFullActionCompleted()
            })
        case .compressImage:
            // A photograph straight from the camera has no file behind it yet, so
            // one is written at full quality: the tool needs something to measure
            // its own result against.
            guard let data = uiImage.jpegData(compressionQuality: 1.0),
                  let source = ImageCompressViewModel.makeSource(data: data, filename: filename, index: 0) else {
                self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
                return
            }
            self.startImageCompression(sources: [source])
        case .passportPhoto:
            // Not through `convertUiImageToPdf`: an identity photo is only
            // correct at one physical size, and that path makes the page as big
            // as the bitmap. The tool builds its own 35 × 45 mm page.
            self.passportPhotoViewModel.run(image: uiImage, onCreatePdf: { [weak self] document, name in
                var pdf = Pdf(pdfDocument: document)
                pdf.updateFilename(name)
                self?.asyncPdf = AsyncOperation(status: .data(pdf))
                self?.trackFullActionCompleted()
            })
        default:
            // Deliberately not inside `convertUiImageToPdf`: the three cases
            // above reach it too, and a cut-out, an edited picture and a meme
            // are the user's own framing — nothing in them should be turned.
            Task { @MainActor in
                let upright = await self.uprightedIfDocument(uiImage)
                self.convertUiImageToPdf(uiImage: upright, filename: filename)
            }
        }
    }

    /// A photographed page, turned the right way up. Reports the turn so it can
    /// be weighed against `page_rotated`, which is the hand-work this is meant
    /// to remove.
    private func uprightedIfDocument(_ image: UIImage) async -> UIImage {
        let upright = await ImageOrientationUtility.uprighted(image)
        if upright !== image {
            self.analyticsManager.track(event: .imageUprighted)
        }
        return upright
    }

    /// Files chosen in the browser rather than in the photo library.
    @MainActor
    private func compressImages(fileUrls: [URL]) {
        let sources = fileUrls.enumerated().compactMap { index, url -> ImageCompressSource? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return ImageCompressViewModel.makeSource(data: data, filename: url.filename, index: index)
        }
        guard !sources.isEmpty else {
            self.asyncImageLoading = AsyncOperation(status: .error(.unknownError))
            return
        }
        self.startImageCompression(sources: sources)
    }

    @MainActor
    private func startImageCompression(sources: [ImageCompressSource]) {
        self.imageCompressViewModel.run(sources: sources, onFinished: { [weak self] in
            // Like the other two tools that end in a picture: the job is done when
            // something left the screen, not when a document was made — this one
            // never makes a document at all.
            self?.trackFullActionCompleted()
        })
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
            self.activeSheet = .scanner
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
        // The shortcut strip learns from every door into a tool except this one,
        // which is the door nine out of ten people use: the Tools screen, search
        // and the Mac menu all registered their picks, the home tiles never did.
        // So "most used" was built from everything but the main flow.
        ToolUsageTracker.registerUse(of: action)
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
