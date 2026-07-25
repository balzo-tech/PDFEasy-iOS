//
//  PdfCleanupUtility.swift
//  PdfExpert
//
//  Document-hygiene tools that work on the whole document: drop blank pages, flatten
//  annotations into the page content, invert colors. All three are on-device and free.
//
//  Flatten and invert build on `PdfOverlayUtility.redrawPages`, the same rotation-aware,
//  vector-preserving rebuild used by page numbers and watermarks: text keeps being
//  selectable and searchable, which a rasterizing implementation would destroy.
//

import Foundation
import UIKit
import PDFKit
import SwiftUI

/// The three hygiene operations, so the view model can drive them through one path.
enum PdfCleanupOperation {
    case removeBlankPages
    case flatten
    case invertColors
}

class PdfCleanupUtility {

    // MARK: - Async entry point

    /// Runs `operation` off the main thread and publishes the updated `Pdf` on
    /// `asyncOperation` (shape borrowed from `OcrUtility.makeSearchable`).
    /// `onCompleted` reports how many pages were removed — 0 for the operations that
    /// do not remove any — so the caller can show the right feedback.
    static func run(_ operation: PdfCleanupOperation,
                    pdf: Pdf,
                    asyncOperation: Binding<AsyncOperation<Pdf, PdfError>>,
                    onCompleted: ((Int) -> Void)? = nil) {

        let document = pdf.pdfDocument
        asyncOperation.wrappedValue = AsyncOperation(status: .loading(Progress.undeterminedProgress))

        DispatchQueue.global(qos: .userInitiated).async {
            let result: (document: PDFDocument, removedCount: Int)?
            switch operation {
            case .removeBlankPages:
                result = self.removeBlankPages(from: document)
            case .flatten:
                result = self.flatten(document).map { ($0, 0) }
            case .invertColors:
                result = self.invertColors(of: document).map { ($0, 0) }
            }

            DispatchQueue.main.async {
                guard let result = result else {
                    asyncOperation.wrappedValue = AsyncOperation(status: .error(.unknownError))
                    return
                }
                // Nothing was removed: publish no document at all, so the host does not
                // mark the file as modified (and regenerate every thumbnail) for a
                // no-op. The caller still gets the count and reports it to the user.
                if operation == .removeBlankPages, result.removedCount == 0 {
                    asyncOperation.wrappedValue = AsyncOperation(status: .empty)
                    onCompleted?(0)
                    return
                }
                var newPdf = pdf
                newPdf.updateDocument(result.document)
                asyncOperation.wrappedValue = AsyncOperation(status: .data(newPdf))
                onCompleted?(result.removedCount)
            }
        }
    }

    // MARK: - Blank pages

    /// Indexes of the pages that carry neither text nor meaningful ink.
    ///
    /// Blankness is decided by `PDFUtility.pageIsBlank`, which pairs text extraction
    /// with a low-resolution render — text alone would flag every scanned page as blank.
    static func blankPageIndexes(in document: PDFDocument,
                                 inkThreshold: CGFloat = PDFUtility.blankPageInkThreshold) -> [Int] {
        (0..<document.pageCount).filter { pageIndex in
            guard let page = document.page(at: pageIndex) else { return false }
            return PDFUtility.pageIsBlank(page, inkThreshold: inkThreshold)
        }
    }

    /// Returns a copy of `document` without its blank pages, plus how many were dropped.
    ///
    /// Two deliberate no-ops, both returning the input untouched with `removedCount == 0`:
    /// nothing to remove, and *everything* would be removed (an all-blank document must
    /// not be emptied — the user would lose the file to a tool meant to tidy it).
    static func removeBlankPages(from document: PDFDocument) -> (document: PDFDocument, removedCount: Int) {
        let blankIndexes = self.blankPageIndexes(in: document)
        guard !blankIndexes.isEmpty, blankIndexes.count < document.pageCount else {
            return (document, 0)
        }
        guard let copy = document.dataRepresentation().flatMap({ PDFDocument(data: $0) }) else {
            return (document, 0)
        }
        // Remove from the back so the earlier indexes stay valid.
        for pageIndex in blankIndexes.sorted(by: >) {
            copy.removePage(at: pageIndex)
        }
        return (copy, blankIndexes.count)
    }

    // MARK: - Flatten

    /// Bakes annotations into the page content: signatures, free text and filled fields
    /// stay visible but stop being editable, and form widgets lose their interactivity.
    ///
    /// This is the same trade-off the share post-process already makes; here it is the
    /// explicit purpose — a flattened document cannot be silently altered downstream.
    static func flatten(_ document: PDFDocument) -> PDFDocument? {
        PdfOverlayUtility.redrawPages(of: document) { _, _, _ in }
    }

    // MARK: - Invert colors

    /// Inverts every page (dark background, light text) for comfortable reading.
    ///
    /// Implemented as a white fill in `.difference` blend mode *over* the redrawn page
    /// rather than by rasterizing an inverted bitmap: the content underneath stays
    /// vector, so text remains selectable and the archive's full-text search keeps
    /// working on the result.
    ///
    /// The white underlay is not cosmetic. A PDF page has no background — unpainted
    /// areas are transparent — and `.difference` against nothing leaves white as white,
    /// so without an opaque backdrop the "inverted" page comes back unchanged.
    static func invertColors(of document: PDFDocument) -> PDFDocument? {
        PdfOverlayUtility.redrawPages(of: document, underlay: { context, pageSize in
            context.saveGState()
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: pageSize))
            context.restoreGState()
        }, overlay: { context, _, pageSize in
            context.saveGState()
            context.setBlendMode(.difference)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: pageSize))
            context.restoreGState()
        })
    }
}
