//
//  PdfCompressViewModel.swift
//  PdfExpert
//
//  "Compress PDF" (free): pick a preset, see what it actually costs, then keep it.
//
//  The compression is run for real before anything is saved, rather than
//  estimated: an estimate on a PDF is guesswork (it depends on what the pages are
//  made of), and the one number the user cares about — how much smaller it got —
//  is the number a real run produces. The result is saved as a **new** document,
//  so the original stays as the way back from a preset that was too aggressive.
//

import Foundation
import Factory
import SwiftUI
import PDFKit

extension Container {
    var pdfCompressViewModel: Factory<PdfCompressViewModel> {
        self { PdfCompressViewModel() }
    }
}

class PdfCompressViewModel: ObservableObject {

    @Published var editorShow: Bool = false
    @Published var successAlertShow: Bool = false
    @Published var preset: CompressionPreset = .balanced {
        didSet {
            guard oldValue != self.preset else { return }
            // `didSet` is nonisolated; the run itself has to hop to the main actor.
            Task { @MainActor in self.compress() }
        }
    }

    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var asyncSave: AsyncEmptyFailable<SharedLocalizedError> = .idle

    /// Result of the preset currently selected, nil while it is being computed.
    @Published private(set) var result: CompressionResult? = nil
    @Published private(set) var isCompressing: Bool = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var originalByteCount: Int = 0
    @Published private(set) var previewImage: UIImage? = nil

    var canSave: Bool { self.result?.isSmaller == true && !self.isCompressing }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.repository) private var repository

    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()

    private var sourcePdf: Pdf? = nil
    private var onCompleted: (() -> ())? = nil
    /// Bumped on every run so a slow preset finishing late cannot overwrite the
    /// result of the preset the user has since switched to.
    private var runToken: Int = 0

    @MainActor
    func run(pdf: Pdf?, onCompleted: (() -> ())?) {
        self.onCompleted = onCompleted
        if let pdf = pdf {
            self.asyncImportedPdf = .init(status: .data(pdf))
        } else {
            self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForExtract)
        }
    }

    private func onImportCompleted(pdf: Pdf) {
        guard pdf.pageCount > 0 else {
            self.asyncSave = .error(.unknownError)
            return
        }
        self.sourcePdf = pdf
        self.originalByteCount = pdf.rawData?.count ?? 0
        self.preset = .balanced
        // Defer so the import sheet has finished dismissing before the editor.
        DispatchQueue.main.async {
            self.analyticsManager.track(event: .reportScreen(.compress))
            self.analyticsManager.track(event: .compressionStarted)
            self.editorShow = true
            self.compress()
        }
    }

    // MARK: - Compression

    @MainActor
    private func compress() {
        guard let document = self.sourcePdf?.pdfDocument else { return }
        self.runToken += 1
        let token = self.runToken
        let preset = self.preset

        self.isCompressing = true
        self.progress = 0
        self.result = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let result = PdfCompressUtility.compress(document: document, preset: preset) { fraction in
                DispatchQueue.main.async {
                    guard token == self.runToken else { return }
                    self.progress = fraction
                }
            }
            // The preview is the first page of the *result*, so what the user
            // judges the quality on is what will be saved.
            let preview = result?.document.page(at: 0).map {
                $0.thumbnail(of: CGSize(width: 600, height: 800), for: .mediaBox)
            }
            DispatchQueue.main.async {
                guard token == self.runToken else { return }
                self.isCompressing = false
                self.result = result
                self.previewImage = preview
            }
        }
    }

    // MARK: - Save

    @MainActor
    func save() {
        guard let sourcePdf = self.sourcePdf, let result = self.result, result.isSmaller else { return }

        // A new Pdf rather than a mutated copy: `Pdf` carries the Core Data
        // storeId, so saving a mutated one would overwrite the original — and the
        // original is what the user falls back on when a preset went too far.
        var compressedPdf = Pdf(pdfDocument: result.document)
        compressedPdf.updateFilename(sourcePdf.filename + "-compressed")
        do {
            _ = try self.repository.savePdf(pdf: compressedPdf)
        } catch {
            self.asyncSave = .error(.unknownError)
            return
        }
        let savedPercent = Int((result.savedFraction * 100).rounded())
        self.analyticsManager.track(event: .compressionCompleted(preset: self.preset, savedPercent: savedPercent))
        self.editorShow = false
        self.successAlertShow = true
        self.cleanUp()
        self.onCompleted?()
    }

    @MainActor
    func cancel() {
        self.editorShow = false
        self.cleanUp()
    }

    private func cleanUp() {
        self.runToken += 1
        self.sourcePdf = nil
        self.result = nil
        self.previewImage = nil
        self.originalByteCount = 0
        self.isCompressing = false
        self.progress = 0
    }
}
