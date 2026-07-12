//
//  PdfConvertViewModel.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//
//  Drives the PDF → Word / PowerPoint / Excel(CSV) conversions (PREMIUM). Unlike
//  every other tool these upload the document to the Stirling conversion service,
//  so the flow adds a one-time privacy disclosure before the (existing) premium
//  gate. Shape mirrors PdfExportViewModel: own import flow when no pdf is passed,
//  an AsyncOperation loader, and an Identifiable result driving a share sheet whose
//  temp files are cleaned up on dismiss.
//

import Foundation
import Factory
import SwiftUI
import Combine

extension Container {
    var pdfConvertViewModel: Factory<PdfConvertViewModel> {
        self { PdfConvertViewModel() }
    }
}

/// The output formats a PDF can be converted to via the Stirling API. Each maps to
/// a single `StirlingOperation`.
enum PdfConvertFormat: CaseIterable {
    case word
    case powerpoint
    case csv

    var operation: StirlingOperation {
        switch self {
        case .word: return .pdfToWord
        case .powerpoint: return .pdfToPresentation
        case .csv: return .pdfToCsv
        }
    }

    var displayName: String {
        switch self {
        case .word: return String(localized: "PDF to Word")
        case .powerpoint: return String(localized: "PDF to PowerPoint")
        case .csv: return String(localized: "PDF to Excel")
        }
    }

    var systemImageName: String {
        switch self {
        case .word: return "doc.text"
        case .powerpoint: return "rectangle.on.rectangle"
        case .csv: return "tablecells"
        }
    }

    var outputDescription: String {
        switch self {
        case .word: return String(localized: "Convert your PDF into an editable Word document (.docx)")
        case .powerpoint: return String(localized: "Turn your PDF into an editable PowerPoint presentation (.pptx)")
        case .csv: return String(localized: "Extract your PDF tables into a spreadsheet (.csv)")
        }
    }
}

class PdfConvertViewModel: ObservableObject {

    struct ConvertResult: Identifiable {
        let id = UUID()
        let urls: [URL]
        let pdf: Pdf
    }

    @Published var monetizationShow: Bool = false
    // One-time privacy disclosure shown before the very first online conversion.
    @Published var disclosureAlertShow: Bool = false
    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var asyncConvert: AsyncOperation<ConvertResult, StirlingApiError> = AsyncOperation(status: .empty) {
        didSet {
            if let result = self.asyncConvert.data {
                self.pendingCleanupUrls = result.urls
                self.convertResultToShare = result
                self.asyncConvert = AsyncOperation(status: .empty)
            }
        }
    }
    @Published var convertResultToShare: ConvertResult? = nil

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.cacheManager) private var cacheManager
    @Injected(\.stirlingApiManager) private var stirlingApiManager

    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()

    private var toBeConvertedPdf: Pdf? = nil
    // The chosen format is stashed while the disclosure / paywall is shown, so the
    // conversion can resume once the user accepts (mirrors PdfExportViewModel).
    private var pendingFormat: PdfConvertFormat? = nil
    // Files to delete once the share sheet is dismissed.
    private var pendingCleanupUrls: [URL] = []
    private var cancellables: Set<AnyCancellable> = []

    /// Entry point. Each Home tile preselects its format. With a pdf (from the editor)
    /// the flow runs straight away; with nil (from Home) it runs its own import first.
    @MainActor
    func convert(pdf: Pdf?, format: PdfConvertFormat) {
        self.pendingFormat = format
        if let pdf = pdf {
            self.asyncImportedPdf = .init(status: .data(pdf))
        } else {
            self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForExtract)
        }
    }

    private func onImportCompleted(pdf: Pdf) {
        guard pdf.pageCount > 0 else {
            self.asyncConvert = AsyncOperation(status: .error(.unknownError))
            return
        }
        guard let format = self.pendingFormat else {
            assertionFailure("Missing expected format for the conversion flow")
            return
        }
        self.toBeConvertedPdf = pdf
        self.analyticsManager.track(event: .reportScreen(.convert))
        // Defer so any import sheet finishes dismissing before the disclosure /
        // paywall / share sheet is presented on the same hierarchy.
        DispatchQueue.main.async {
            self.runDisclosureGate(format: format)
        }
    }

    // MARK: - Privacy disclosure (one-time)

    /// The very first online conversion asks for consent (the document leaves the
    /// device). Once accepted the flag is persisted and we never ask again.
    @MainActor
    private func runDisclosureGate(format: PdfConvertFormat) {
        if self.cacheManager.pdfConvertPrivacyAccepted {
            self.startConvert(format: format)
        } else {
            self.pendingFormat = format
            self.disclosureAlertShow = true
        }
    }

    @MainActor
    func onDisclosureAccepted() {
        self.cacheManager.pdfConvertPrivacyAccepted = true
        self.disclosureAlertShow = false
        guard let format = self.pendingFormat else { return }
        // Defer so the alert finishes dismissing before the next presentation.
        DispatchQueue.main.async {
            self.startConvert(format: format)
        }
    }

    @MainActor
    func onDisclosureCancelled() {
        self.disclosureAlertShow = false
        self.pendingFormat = nil
        self.toBeConvertedPdf = nil
    }

    // MARK: - Premium gate

    @MainActor
    func onMonetizationClose() {
        let format = self.pendingFormat
        self.pendingFormat = nil
        if let format, self.store.isPremium.value {
            self.performConvert(format: format)
        }
    }

    /// Premium gate, mirroring PdfExportViewModel: subscribers convert immediately;
    /// everyone else sees the paywall and the conversion resumes after purchase.
    @MainActor
    private func startConvert(format: PdfConvertFormat) {
        if self.store.isPremium.value {
            self.performConvert(format: format)
        } else {
            self.pendingFormat = format
            self.monetizationShow = true
        }
    }

    // MARK: - Network conversion

    @MainActor
    private func performConvert(format: PdfConvertFormat) {
        guard let pdf = self.toBeConvertedPdf, let pdfData = pdf.rawData else {
            self.asyncConvert = AsyncOperation(status: .error(.unknownError))
            return
        }
        self.analyticsManager.track(event: .convertStarted(format: format))
        self.asyncConvert = AsyncOperation(status: .loading(Progress.undeterminedProgress))

        self.stirlingApiManager.process(pdfData: pdfData,
                                        filename: pdf.filename,
                                        operation: format.operation)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let error) = completion {
                    self.asyncConvert = AsyncOperation(status: .error(error))
                    self.toBeConvertedPdf = nil
                }
            }, receiveValue: { [weak self] result in
                guard let self = self else { return }
                do {
                    let url = try Self.writeResult(result, baseName: pdf.filename)
                    self.asyncConvert = AsyncOperation(status: .data(ConvertResult(urls: [url], pdf: pdf)))
                    self.analyticsManager.track(event: .convertCompleted(format: format))
                } catch {
                    self.asyncConvert = AsyncOperation(status: .error(.unknownError))
                }
                self.toBeConvertedPdf = nil
            })
            .store(in: &self.cancellables)
    }

    func onShareDismiss() {
        Self.cleanupFiles(self.pendingCleanupUrls)
        self.pendingCleanupUrls = []
    }

    // MARK: - File output (pure, unit-testable)

    /// Writes the converted document to the temporary directory as
    /// `<sanitized-filename>.<suggestedFileExtension>` and returns its URL.
    static func writeResult(_ result: StirlingResult, baseName: String) throws -> URL {
        let url = Self.outputURL(baseName: baseName, fileExtension: result.suggestedFileExtension)
        try result.data.write(to: url)
        return url
    }

    static func outputURL(baseName: String, fileExtension: String) -> URL {
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.sanitizedFilename(baseName))
            .appendingPathExtension(fileExtension)
    }

    /// Strips characters that are illegal (or awkward) in a filename. Falls back to a
    /// generic name when nothing is left. Mirrors PdfExportUtility's sanitizer.
    static func sanitizedFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.controlCharacters)
            .union(.newlines)
        let sanitized = filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? "document" : sanitized
    }

    /// Deletes every produced file, ignoring individual failures.
    static func cleanupFiles(_ urls: [URL]) {
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("PdfConvertViewModel - Failed to delete temporary file at '\(url)'. Error: \(error)")
            }
        }
    }
}
