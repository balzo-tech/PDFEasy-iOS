//
//  PdfAdvancedToolViewModel.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//
//  Drives the three PDF-in / PDF-out Stirling tools — Convert to PDF/A, Repair and
//  Sanitize (all PREMIUM). Like the Office conversions they upload the document to
//  the Stirling service, so the flow reuses the same one-time online-processing
//  privacy disclosure (CacheManager.pdfConvertPrivacyAccepted — it is the very same
//  "your PDF leaves the device" consent) before the premium gate. Unlike them the
//  result is itself a PDF, so instead of a share sheet the processed document is
//  saved straight to the archive (repository.savePdf) and a success alert is shown.
//  Shape otherwise mirrors PdfConvertViewModel: own import flow when no pdf is
//  passed, disclosure + premium gates, and an async loader.
//

import Foundation
import Factory
import SwiftUI
import Combine

extension Container {
    var pdfAdvancedToolViewModel: Factory<PdfAdvancedToolViewModel> {
        self { PdfAdvancedToolViewModel() }
    }
}

/// The PDF-producing Stirling tools. Each maps to a single `StirlingOperation` and
/// appends a suffix to the source filename for the copy saved to the archive.
enum PdfAdvancedTool: String, CaseIterable {
    case pdfa
    case repair
    case sanitize

    var operation: StirlingOperation {
        switch self {
        case .pdfa: return .pdfToPdfa
        case .repair: return .repair
        case .sanitize: return .sanitize
        }
    }

    var displayName: String {
        switch self {
        case .pdfa: return String(localized: "PDF/A")
        case .repair: return String(localized: "Repair PDF")
        case .sanitize: return String(localized: "Sanitize PDF")
        }
    }

    var systemImageName: String {
        switch self {
        case .pdfa: return "checkmark.seal"
        case .repair: return "wrench.and.screwdriver"
        case .sanitize: return "shield.checkered"
        }
    }

    /// Appended to the source filename for the archived output.
    var filenameSuffix: String {
        switch self {
        case .pdfa: return "-pdfa"
        case .repair: return "-repaired"
        case .sanitize: return "-sanitized"
        }
    }

    /// Per-tool success-alert message (localized). Kept per-case rather than
    /// interpolated so every language reads naturally.
    var successMessage: String {
        switch self {
        case .pdfa: return String(localized: "Your PDF/A file has been saved to your archive.")
        case .repair: return String(localized: "Your repaired file has been saved to your archive.")
        case .sanitize: return String(localized: "Your sanitized file has been saved to your archive.")
        }
    }
}

class PdfAdvancedToolViewModel: ObservableObject {

    @Published var monetizationShow: Bool = false
    // One-time privacy disclosure shown before the very first online processing.
    @Published var disclosureAlertShow: Bool = false
    // Confirmation that the processed PDF was saved to the archive.
    @Published var successAlertShow: Bool = false
    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    // Loading / error state of the network processing (no data payload: on success the
    // PDF is saved and a success alert is shown, so only loading + error matter here).
    @Published var asyncRun: AsyncEmptyFailable<StirlingApiError> = .idle

    /// Message shown in the success alert; set per tool immediately before the alert.
    private(set) var successMessage: String = ""

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.cacheManager) private var cacheManager
    @Injected(\.stirlingApiManager) private var stirlingApiManager
    @Injected(\.repository) private var repository

    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()

    private var toBeProcessedPdf: Pdf? = nil
    // The chosen tool is stashed while the disclosure / paywall is shown, so the run
    // can resume once the user accepts (mirrors PdfConvertViewModel).
    private var pendingTool: PdfAdvancedTool? = nil
    // Invoked after a successful save (Home tracks completion and goes to the archive).
    private var onCompleted: (() -> ())? = nil
    private var cancellables: Set<AnyCancellable> = []

    /// Entry point. Each Home tile preselects its tool. With a pdf (from the editor)
    /// the flow runs straight away; with nil (from Home) it runs its own import first.
    @MainActor
    func run(pdf: Pdf?, tool: PdfAdvancedTool, onCompleted: (() -> ())?) {
        self.pendingTool = tool
        self.onCompleted = onCompleted
        if let pdf = pdf {
            self.asyncImportedPdf = .init(status: .data(pdf))
        } else {
            self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForExtract)
        }
    }

    private func onImportCompleted(pdf: Pdf) {
        guard pdf.pageCount > 0 else {
            self.asyncRun = .error(.unknownError)
            return
        }
        guard let tool = self.pendingTool else {
            assertionFailure("Missing expected tool for the advanced tool flow")
            return
        }
        self.toBeProcessedPdf = pdf
        self.analyticsManager.track(event: .reportScreen(.advancedTool))
        // Defer so any import sheet finishes dismissing before the disclosure /
        // paywall is presented on the same hierarchy.
        DispatchQueue.main.async {
            self.runDisclosureGate(tool: tool)
        }
    }

    // MARK: - Privacy disclosure (one-time, shared with the convert flow)

    /// The very first online processing asks for consent (the document leaves the
    /// device). Once accepted the flag is persisted and we never ask again — and it
    /// is the same flag the Office conversions use, so accepting in either flow
    /// suppresses the disclosure everywhere.
    @MainActor
    private func runDisclosureGate(tool: PdfAdvancedTool) {
        if self.cacheManager.pdfConvertPrivacyAccepted {
            self.startProcess(tool: tool)
        } else {
            self.pendingTool = tool
            self.disclosureAlertShow = true
        }
    }

    @MainActor
    func onDisclosureAccepted() {
        self.cacheManager.pdfConvertPrivacyAccepted = true
        self.disclosureAlertShow = false
        guard let tool = self.pendingTool else { return }
        // Defer so the alert finishes dismissing before the next presentation.
        DispatchQueue.main.async {
            self.startProcess(tool: tool)
        }
    }

    @MainActor
    func onDisclosureCancelled() {
        self.disclosureAlertShow = false
        self.pendingTool = nil
        self.toBeProcessedPdf = nil
    }

    // MARK: - Premium gate

    @MainActor
    func onMonetizationClose() {
        let tool = self.pendingTool
        self.pendingTool = nil
        if let tool, self.store.isPremium.value {
            self.performProcess(tool: tool)
        }
    }

    /// Premium gate, mirroring PdfConvertViewModel: subscribers proceed immediately;
    /// everyone else sees the paywall and the run resumes after purchase.
    @MainActor
    private func startProcess(tool: PdfAdvancedTool) {
        if self.store.isPremium.value {
            self.performProcess(tool: tool)
        } else {
            self.pendingTool = tool
            self.monetizationShow = true
        }
    }

    // MARK: - Network processing + archive save

    @MainActor
    private func performProcess(tool: PdfAdvancedTool) {
        guard let pdf = self.toBeProcessedPdf, let pdfData = pdf.rawData else {
            self.asyncRun = .error(.unknownError)
            return
        }
        self.analyticsManager.track(event: .advancedToolStarted(tool: tool))
        self.asyncRun = .loading(Progress.undeterminedProgress)

        self.stirlingApiManager.process(pdfData: pdfData,
                                        filename: pdf.filename,
                                        operation: tool.operation)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let error) = completion {
                    self.asyncRun = .error(error)
                    self.toBeProcessedPdf = nil
                }
            }, receiveValue: { [weak self] result in
                guard let self = self else { return }
                self.handleResult(result, tool: tool, sourceFilename: pdf.filename)
                self.toBeProcessedPdf = nil
            })
            .store(in: &self.cancellables)
    }

    /// Builds a `Pdf` from the processed bytes, saves it to the archive, and shows the
    /// success alert. Invalid PDF data (a mangled/empty response) surfaces a localized
    /// error and nothing is saved.
    private func handleResult(_ result: StirlingResult, tool: PdfAdvancedTool, sourceFilename: String) {
        guard var processedPdf = Pdf(data: result.data) else {
            self.asyncRun = .error(.invalidResponse)
            return
        }
        processedPdf.updateFilename(sourceFilename + tool.filenameSuffix)
        do {
            _ = try self.repository.savePdf(pdf: processedPdf)
        } catch {
            self.asyncRun = .error(.unknownError)
            return
        }
        self.asyncRun = .idle
        self.successMessage = tool.successMessage
        self.successAlertShow = true
        self.analyticsManager.track(event: .advancedToolCompleted(tool: tool))
        self.onCompleted?()
    }
}
