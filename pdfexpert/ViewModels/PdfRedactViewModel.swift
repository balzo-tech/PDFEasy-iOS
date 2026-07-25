//
//  PdfRedactViewModel.swift
//  PdfExpert
//
//  "Redact PDF" (PREMIUM): drag boxes over what must disappear, then apply.
//
//  The result is always saved as a **new** document (`-redacted`): redaction is
//  irreversible, and overwriting the original would leave the user with no way back
//  from a box in the wrong place.
//

import Foundation
import Factory
import SwiftUI
import PDFKit

extension Container {
    var pdfRedactViewModel: Factory<PdfRedactViewModel> {
        self { PdfRedactViewModel() }
    }
}

class PdfRedactViewModel: ObservableObject {

    @Published var monetizationShow: Bool = false
    @Published var editorShow: Bool = false
    /// "The redacted pages become images" warning, shown before anything is applied.
    @Published var confirmAlertShow: Bool = false
    @Published var successAlertShow: Bool = false

    @Published var pageImages: [UIImage] = []
    @Published var pageIndex: Int = 0
    @Published private(set) var boxes: [RedactionBox] = []

    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var asyncRedact: AsyncEmptyFailable<SharedLocalizedError> = .idle

    var canApply: Bool { !self.boxes.isEmpty }
    var pageCount: Int { self.pageImages.count }
    var currentPageBoxes: [RedactionBox] { self.boxes.filter { $0.pageIndex == self.pageIndex } }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.repository) private var repository

    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()

    private var toBeRedactedPdf: Pdf? = nil
    private var onCompleted: (() -> ())? = nil

    /// Entry point. With a pdf (from the editor) the flow starts immediately; with nil
    /// (from Home) the tool runs its own import first.
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
            self.asyncRedact = .error(.unknownError)
            return
        }
        self.toBeRedactedPdf = pdf
        // Defer so the import sheet finishes dismissing before the paywall / editor.
        DispatchQueue.main.async {
            self.startFlow(pdf: pdf)
        }
    }

    // MARK: - Premium gate

    @MainActor
    private func startFlow(pdf: Pdf) {
        if self.store.isPremium.value {
            self.presentEditor(pdf: pdf)
        } else {
            self.monetizationShow = true
        }
    }

    @MainActor
    func onMonetizationClose() {
        guard let pdf = self.toBeRedactedPdf, self.store.isPremium.value else {
            self.toBeRedactedPdf = nil
            return
        }
        self.presentEditor(pdf: pdf)
    }

    @MainActor
    private func presentEditor(pdf: Pdf) {
        self.boxes = []
        self.pageIndex = 0
        self.pageImages = PDFUtility.generatePdfThumbnails(pdfDocument: pdf.pdfDocument,
                                                           size: nil).compactMap { $0 }
        self.analyticsManager.track(event: .reportScreen(.redact))
        self.analyticsManager.track(event: .redactionStarted)
        self.editorShow = true
    }

    // MARK: - Box editing

    /// `rect` is normalized (0…1, top-left origin) against the displayed page.
    @MainActor
    func addBox(normalizedRect: CGRect) {
        // Ignore accidental taps: a box smaller than half a percent of the page hides
        // nothing and would only clutter the list.
        guard normalizedRect.width > 0.005, normalizedRect.height > 0.005 else { return }
        self.boxes.append(RedactionBox(pageIndex: self.pageIndex, rect: normalizedRect))
    }

    @MainActor
    func removeLastBoxOnCurrentPage() {
        guard let lastIndex = self.boxes.lastIndex(where: { $0.pageIndex == self.pageIndex }) else { return }
        self.boxes.remove(at: lastIndex)
    }

    @MainActor
    func clearBoxes() {
        self.boxes = []
    }

    @MainActor
    func cancel() {
        self.editorShow = false
        self.boxes = []
        self.pageImages = []
        self.toBeRedactedPdf = nil
    }

    // MARK: - Apply

    @MainActor
    func requestApply() {
        guard self.canApply else { return }
        self.confirmAlertShow = true
    }

    @MainActor
    func onApplyConfirmed() {
        self.confirmAlertShow = false
        guard let pdf = self.toBeRedactedPdf else {
            self.asyncRedact = .error(.unknownError)
            return
        }
        let boxes = self.boxes
        self.editorShow = false

        DispatchQueue.main.async {
            self.apply(to: pdf, boxes: boxes)
        }
    }

    @MainActor
    private func apply(to pdf: Pdf, boxes: [RedactionBox]) {
        self.asyncRedact = .loading(Progress.undeterminedProgress)
        let document = pdf.pdfDocument
        let redactedPageCount = Set(boxes.map { $0.pageIndex }).count

        DispatchQueue.global(qos: .userInitiated).async {
            let redactedDocument = PdfRedactUtility.redact(document: document, boxes: boxes)
            DispatchQueue.main.async {
                guard let redactedDocument = redactedDocument else {
                    self.asyncRedact = .error(.unknownError)
                    self.cleanUp()
                    return
                }
                // A *new* Pdf, not a copy of the source: `Pdf` carries the Core Data
                // storeId, so mutating the imported one and saving would overwrite the
                // original — the exact thing redaction must never do, since it cannot
                // be undone. The original stays in the archive as the way back.
                var redactedPdf = Pdf(pdfDocument: redactedDocument)
                redactedPdf.updateFilename(pdf.filename + "-redacted")
                do {
                    _ = try self.repository.savePdf(pdf: redactedPdf)
                } catch {
                    self.asyncRedact = .error(.unknownError)
                    self.cleanUp()
                    return
                }
                self.asyncRedact = .idle
                self.successAlertShow = true
                self.analyticsManager.track(event: .redactionCompleted(boxCount: boxes.count,
                                                                       pageCount: redactedPageCount))
                self.cleanUp()
                self.onCompleted?()
            }
        }
    }

    private func cleanUp() {
        self.boxes = []
        self.pageImages = []
        self.toBeRedactedPdf = nil
    }
}
