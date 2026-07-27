//
//  PdfExtractViewModel.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfExtractViewModel: Factory<PdfExtractViewModel> {
        self { PdfExtractViewModel() }
    }
}

typealias ExtractCompletedCallback = (() -> ())

class PdfExtractViewModel: ObservableObject {

    /// True while the range editor is on screen, cover or pushed screen — see
    /// the same flag on `PdfSplitViewModel`.
    @Published var showPageRangeEditor: Bool = false
    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var toBeExtractedPdf: Pdf? = nil
    @Published var pageRanges: [ClosedRange<Int>] = []
    @Published var asyncExtract: AsyncEmptyFailable<PdfExtractError> = .idle

    @Injected(\.repository) private var repository
    @Injected(\.analyticsManager) private var analyticsManager

    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()

    var totalPages: Int = 0

    private var onExtractCompleted: ExtractCompletedCallback?

    func extract(pdf: Pdf?, onExtractCompleted: ExtractCompletedCallback?) {
        self.onExtractCompleted = onExtractCompleted
        if let pdf = pdf {
            self.asyncImportedPdf = .init(status: .data(pdf))
        } else {
            self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForExtract)
        }
    }

    /// Prepares the ranges for a document the caller already has and leaves the
    /// presenting to it — the editor pushes the range editor. Same contract as
    /// `PdfSplitViewModel.prepare`.
    @discardableResult
    func prepare(pdf: Pdf, onExtractCompleted: ExtractCompletedCallback?) -> Bool {
        self.onExtractCompleted = onExtractCompleted
        return self.prepareRanges(for: pdf)
    }

    func onPageRangeEditingCancelled() {
        self.toBeExtractedPdf = nil
        self.showPageRangeEditor = false
    }

    func onPageRangeEditingConfirmed() {
        self.showPageRangeEditor = false
    }

    @MainActor
    func onPageRangeEditingCompleted() {
        self.extractPdf()
    }

    private func onImportCompleted(pdf: Pdf) {
        self.prepareRanges(for: pdf)
    }

    @discardableResult
    private func prepareRanges(for pdf: Pdf) -> Bool {
        guard pdf.pageCount > 0 else {
            self.asyncExtract = .error(.pdfNoPage)
            return false
        }
        guard pdf.pageCount > 1 else {
            self.asyncExtract = .error(.pdfSinglePage)
            return false
        }
        self.toBeExtractedPdf = pdf
        self.pageRanges = [0...pdf.pageCount - 1]
        self.totalPages = pdf.pageCount
        self.showPageRangeEditor = true
        return true
    }

    @MainActor
    private func extractPdf() {
        guard let pdf = self.toBeExtractedPdf else {
            self.asyncExtract = .idle
            return
        }
        guard self.pageRanges.count > 0 else {
            assertionFailure("Page range array is empty!")
            self.asyncExtract = .error(.unknownError)
            return
        }
        self.asyncExtract = .loading(Progress.undeterminedProgress)

        Task {
            do {
                let extractedPdf = try await Self.extractPdf(pdf: pdf, pageRanges: self.pageRanges)
                _ = try self.repository.savePdf(pdf: extractedPdf)
                self.asyncExtract = .idle
                self.analyticsManager.track(event: .pdfExtract)
                self.onExtractCompleted?()
            } catch let extractError as PdfExtractError {
                self.asyncExtract = .error(extractError)
            } catch {
                self.asyncExtract = .error(PdfExtractError.convertError(fromError: error))
            }

            self.toBeExtractedPdf = nil
            self.pageRanges = []
            self.totalPages = 0
        }
    }

    /// Merges every requested range into a single new pdf (unlike split, which produces
    /// one pdf per range). The output filename appends "-extracted" to the original.
    private static func extractPdf(pdf: Pdf, pageRanges: [ClosedRange<Int>]) async throws -> Pdf {
        let task = Task<Pdf, Never> {
            let extractedDocument = PDFUtility.extractPages(fromDocument: pdf.pdfDocument, pageRanges: pageRanges)
            var extractedPdf = Pdf(pdfDocument: extractedDocument)
            extractedPdf.updateFilename(pdf.filename + "-extracted")
            return extractedPdf
        }
        return await task.value
    }
}
