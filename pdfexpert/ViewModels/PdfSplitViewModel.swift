//
//  PdfSplitViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfSplitViewModel: Factory<PdfSplitViewModel> {
        self { PdfSplitViewModel() }
    }
}

class PdfSplitViewModel: ObservableObject {
    
    @Published var showPageRangeEditor: Bool = false
    @Published var showSuccess: Bool = false
    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var toBeSplitPdf: Pdf? = nil
    @Published var pageRanges: [ClosedRange<Int>] = []
    @Published var asyncSplit: AsyncEmptyFailable<PdfSplitError> = .idle
    
    @Injected(\.repository) private var repository
    @Injected(\.mainCoordinator) private var mainCoordinator
    
    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()
    
    var totalPages: Int = 0
    
    func split() {
        self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForSplit)
    }
    
    func onPageRangeEditingCancelled() {
        self.toBeSplitPdf = nil
        self.showPageRangeEditor = false
    }
    
    func onPageRangeEditingConfirmed() {
        self.showPageRangeEditor = false
    }
    
    @MainActor
    func onPageRangeEditingCompleted() {
        self.splitPdf()
    }
    
    private func onImportCompleted(pdf: Pdf) {
        guard pdf.pageCount > 0 else {
            self.asyncSplit = .error(.pdfNoPage)
            return
        }
        guard pdf.pageCount > 1 else {
            // TODO: Decide whether pdf must still be saved or not
            self.asyncSplit = .error(.pdfSinglePage)
            return
        }
        self.toBeSplitPdf = pdf
        self.pageRanges = [0...pdf.pageCount - 1]
        self.totalPages = pdf.pageCount
        self.showPageRangeEditor = true
    }
    
    @MainActor
    private func splitPdf() {
        guard let pdf = self.toBeSplitPdf else {
            self.asyncSplit = .idle
            return
        }
        guard self.pageRanges.count > 0 else {
            assertionFailure("Page range array is empty!")
            self.asyncSplit = .error(.unknownError)
            return
        }
        self.asyncSplit = .loading(Progress.undeterminedProgress)
        
        Task {
            do {
                let splitPdfs = try await Self.splitPdf(pdf: pdf, pageRanges: self.pageRanges)
                try self.savePdfs(pdfs: splitPdfs)
                self.asyncSplit = .idle
                self.goToArchive()
            } catch let splitError as PdfSplitError {
                self.asyncSplit = .error(splitError)
            } catch {
                self.asyncSplit = .error(PdfSplitError.convertError(fromError: error))
            }
            
            self.toBeSplitPdf = nil
            self.pageRanges = []
            self.totalPages = 0
        }
    }
    
    private func goToArchive() {
        self.mainCoordinator.goToArchive()
    }
    
    private static func splitPdf(pdf: Pdf, pageRanges: [ClosedRange<Int>]) async throws -> [Pdf] {
        var pdfs: [Pdf] = []
        for pageRange in pageRanges {
            pdfs.append(try await Self.getPdfSlice(fromPdf: pdf, pageRange: pageRange))
        }
        return pdfs
    }
    
    private func savePdfs(pdfs: [Pdf]) throws {
        // Any error is not blocking the entire save sequence
        var occurredError: Error?
        for pdf in pdfs {
            do {
                _ = try self.repository.savePdf(pdf: pdf)
            } catch {
                occurredError = error
            }
        }
        
        if let occurredError {
            throw occurredError
        }
    }
    
    private static func getPdfSlice(fromPdf pdf: Pdf, pageRange: ClosedRange<Int>) async throws -> Pdf {
        guard pageRange.overlaps(0...pdf.pageCount) else {
            throw PdfSplitError.incompatibleRange
        }
        let task = Task<Pdf, Never> {
            var pdfSlice = Pdf()
            let pdfSliceDocument = pdfSlice.pdfDocument
            for pageIndex in pageRange {
                if let page = pdf.pdfDocument.page(at: pageIndex) {
                    pdfSliceDocument.insert(page, at: pdfSliceDocument.pageCount)
                } else {
                    assertionFailure("Missing expected page!")
                }
            }
            pdfSlice.updateFilename(pdfSlice.filename + pageRange.pdfFilenameSuffix)
            return pdfSlice
        }
        return await task.value
    }
}

fileprivate extension ClosedRange where Bound == Int {
    var pdfFilenameSuffix: String {
        "-\(self.lowerBound + 1)-\(self.upperBound + 1)"
    }
}
