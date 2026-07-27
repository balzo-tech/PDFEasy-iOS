//
//  PdfExportViewModel.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfExportViewModel: Factory<PdfExportViewModel> {
        self { PdfExportViewModel() }
    }
}

class PdfExportViewModel: ObservableObject {

    struct ExportResult: Identifiable {
        let id = UUID()
        let urls: [URL]
        let pdf: Pdf
    }

    /// True while the format list is on screen, cover or pushed screen.
    @Published var formatPickerShow: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var asyncExport: AsyncOperation<ExportResult, PdfExportError> = AsyncOperation(status: .empty) {
        didSet {
            if let result = self.asyncExport.data {
                self.pendingCleanupUrls = result.urls
                self.exportResultToShare = result
                self.asyncExport = AsyncOperation(status: .empty)
            }
        }
    }
    @Published var exportResultToShare: ExportResult? = nil

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store

    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()

    private var toBeExportedPdf: Pdf? = nil
    // The chosen format is stashed here when the paywall is shown, so the export can
    // resume after a successful purchase (mirrors PdfShareCoordinator's deferred share).
    private var pendingFormat: PdfExportFormat? = nil
    // Files to delete once the share sheet is dismissed. Kept independently of the
    // sheet's item binding so cleanup is robust regardless of binding timing.
    private var pendingCleanupUrls: [URL] = []

    /// Entry point. With a pdf (from the editor) the format picker opens straight away;
    /// with nil (from Home) the tool runs its own import flow first.
    func export(pdf: Pdf?) {
        if let pdf = pdf {
            self.asyncImportedPdf = .init(status: .data(pdf))
        } else {
            self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForExtract)
        }
    }

    /// The half of `export(pdf:)` that stops short of presenting, for a host
    /// that shows the format list itself — the editor pushes it.
    @discardableResult
    func prepare(pdf: Pdf) -> Bool {
        self.prepareFormatChoice(for: pdf)
    }

    private func onImportCompleted(pdf: Pdf) {
        self.prepareFormatChoice(for: pdf)
    }

    @discardableResult
    private func prepareFormatChoice(for pdf: Pdf) -> Bool {
        guard pdf.pageCount > 0 else {
            self.asyncExport = AsyncOperation(status: .error(.unknownError))
            return false
        }
        self.toBeExportedPdf = pdf
        self.analyticsManager.track(event: .reportScreen(.export))
        self.formatPickerShow = true
        return true
    }

    @MainActor
    func onFormatSelected(_ format: PdfExportFormat) {
        self.formatPickerShow = false
        // Defer so the picker sheet finishes dismissing before the paywall / share sheet
        // is presented on the same hierarchy.
        DispatchQueue.main.async {
            self.startExport(format: format)
        }
    }

    @MainActor
    func onMonetizationClose() {
        let format = self.pendingFormat
        self.pendingFormat = nil
        if let format, self.store.isPremium.value {
            self.performExport(format: format)
        }
    }

    /// Premium gate, mirroring PdfShareCoordinator: subscribers run immediately;
    /// everyone else sees the paywall and the export resumes on a successful purchase.
    @MainActor
    private func startExport(format: PdfExportFormat) {
        if self.store.isPremium.value {
            self.performExport(format: format)
        } else {
            self.pendingFormat = format
            self.monetizationShow = true
        }
    }

    @MainActor
    private func performExport(format: PdfExportFormat) {
        guard let pdf = self.toBeExportedPdf else {
            self.asyncExport = AsyncOperation(status: .error(.unknownError))
            return
        }
        self.analyticsManager.track(event: .exportStarted(format: format))
        self.asyncExport = AsyncOperation(status: .loading(Progress.undeterminedProgress))

        Task {
            do {
                let urls = try await Self.runExport(pdf: pdf, format: format)
                self.asyncExport = AsyncOperation(status: .data(ExportResult(urls: urls, pdf: pdf)))
                self.analyticsManager.track(event: .exportCompleted(format: format))
            } catch let exportError as PdfExportError {
                self.asyncExport = AsyncOperation(status: .error(exportError))
            } catch {
                self.asyncExport = AsyncOperation(status: .error(.unknownError))
            }
            self.toBeExportedPdf = nil
        }
    }

    /// Runs the file-producing work on a background executor (the inner non-isolated
    /// Task), matching the extract flow.
    private static func runExport(pdf: Pdf, format: PdfExportFormat) async throws -> [URL] {
        let task = Task<Result<[URL], PdfExportError>, Never>(priority: .userInitiated) {
            do {
                let urls: [URL]
                switch format {
                case .imagesPng:
                    urls = try PdfExportUtility.exportPageImages(pdf: pdf, asPng: true)
                case .imagesJpeg:
                    urls = try PdfExportUtility.exportPageImages(pdf: pdf, asPng: false)
                case .text:
                    urls = [try PdfExportUtility.exportText(pdf: pdf)]
                case .embeddedImages:
                    urls = try PdfExportUtility.exportEmbeddedImages(pdf: pdf)
                }
                return .success(urls)
            } catch let error as PdfExportError {
                return .failure(error)
            } catch {
                return .failure(.unknownError)
            }
        }
        switch await task.value {
        case .success(let urls): return urls
        case .failure(let error): throw error
        }
    }

    func onShareDismiss() {
        PdfExportUtility.cleanupExportFiles(self.pendingCleanupUrls)
        self.pendingCleanupUrls = []
    }
}
