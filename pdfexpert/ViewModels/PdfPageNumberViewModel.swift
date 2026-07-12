//
//  PdfPageNumberViewModel.swift
//  PdfExpert
//
//  Premium tool that stamps a page number on every page of a PDF. Wraps
//  `PdfOverlayUtility.addPageNumbers`, running the redraw off the main thread and
//  publishing an `AsyncOperation` so the view can show a loader. The input `Pdf`
//  is never mutated: on success a fresh `Pdf` (same filename/password/etc.) is
//  built from the new document and handed to `onConfirm`.
//

import Foundation
import Factory
import SwiftUI
import PDFKit

extension Container {
    var pdfPageNumberViewModel: ParameterFactory<PdfPageNumberViewModel.InputParameter, PdfPageNumberViewModel> {
        self { PdfPageNumberViewModel(inputParameter: $0) }
    }
}

class PdfPageNumberViewModel: ObservableObject {

    struct InputParameter {
        let pdf: Pdf
        let onConfirm: (Pdf) -> Void
    }

    @Published var position: PageNumberPosition = .bottomCenter
    @Published var format: PageNumberFormat = .simple
    @Published var fontSize: CGFloat = 12

    // Drives the loader while the redraw runs; errors surface via the standard
    // async error alert.
    @Published var asyncApply: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty)

    @Injected(\.analyticsManager) private var analyticsManager

    private let pdf: Pdf
    private let onConfirm: (Pdf) -> Void

    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        self.onConfirm = inputParameter.onConfirm
    }

    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.pageNumbers))
    }

    /// Applies the page numbers on a background queue, then rebuilds the `Pdf` and
    /// notifies `onConfirm` on the main thread. `onCompletion` lets the view dismiss
    /// itself once the new document has been handed back.
    func apply(onCompletion: @escaping () -> Void) {
        let style = PageNumberStyle(position: self.position,
                                    format: self.format,
                                    fontSize: self.fontSize)
        let sourcePdf = self.pdf
        let position = self.position
        let format = self.format

        self.analyticsManager.track(event: .pageNumbersStarted)
        self.asyncApply = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))

        DispatchQueue.global(qos: .userInitiated).async {
            let newDocument = PdfOverlayUtility.addPageNumbers(to: sourcePdf.pdfDocument, style: style)
            DispatchQueue.main.async {
                guard let newDocument else {
                    self.asyncApply = AsyncOperation(status: .error(.unknownError))
                    return
                }
                var newPdf = sourcePdf
                newPdf.updateDocument(newDocument)
                self.analyticsManager.track(event: .pageNumbersCompleted(position: position, format: format))
                self.asyncApply = AsyncOperation(status: .empty)
                self.onConfirm(newPdf)
                onCompletion()
            }
        }
    }
}
