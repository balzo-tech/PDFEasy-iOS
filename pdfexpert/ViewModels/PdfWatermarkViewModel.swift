//
//  PdfWatermarkViewModel.swift
//  PdfExpert
//
//  Premium tool that stamps a text watermark across every page of a PDF. Wraps
//  `PdfOverlayUtility.addWatermark`, running the redraw off the main thread and
//  publishing an `AsyncOperation` so the view can show a loader. The input `Pdf`
//  is never mutated: on success a fresh `Pdf` (same filename/password/etc.) is
//  built from the new document and handed to `onConfirm`.
//

import Foundation
import Factory
import SwiftUI
import PDFKit

extension Container {
    var pdfWatermarkViewModel: ParameterFactory<PdfWatermarkViewModel.InputParameter, PdfWatermarkViewModel> {
        self { PdfWatermarkViewModel(inputParameter: $0) }
    }
}

class PdfWatermarkViewModel: ObservableObject {

    struct InputParameter {
        let pdf: Pdf
        let onConfirm: (Pdf) -> Void
    }

    @Published var text: String = ""
    @Published var opacity: CGFloat = 0.3
    @Published var layout: WatermarkLayout = .diagonal
    @Published var fontSize: CGFloat = 48

    // Drives the loader while the redraw runs; errors surface via the standard
    // async error alert.
    @Published var asyncApply: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty)

    /// The Apply button is disabled until there's actual (non-whitespace) text.
    var canApply: Bool {
        !self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Injected(\.analyticsManager) private var analyticsManager

    private let pdf: Pdf
    private let onConfirm: (Pdf) -> Void

    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        self.onConfirm = inputParameter.onConfirm
    }

    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.watermark))
    }

    /// Applies the watermark on a background queue, then rebuilds the `Pdf` and
    /// notifies `onConfirm` on the main thread. `onCompletion` lets the view dismiss
    /// itself once the new document has been handed back.
    func apply(onCompletion: @escaping () -> Void) {
        let trimmedText = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let style = WatermarkStyle(text: trimmedText,
                                   opacity: self.opacity,
                                   layout: self.layout,
                                   fontSize: self.fontSize)
        let sourcePdf = self.pdf
        let layout = self.layout

        self.analyticsManager.track(event: .watermarkStarted)
        self.asyncApply = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))

        DispatchQueue.global(qos: .userInitiated).async {
            let newDocument = PdfOverlayUtility.addWatermark(to: sourcePdf.pdfDocument, style: style)
            DispatchQueue.main.async {
                guard let newDocument else {
                    self.asyncApply = AsyncOperation(status: .error(.unknownError))
                    return
                }
                var newPdf = sourcePdf
                newPdf.updateDocument(newDocument)
                self.analyticsManager.track(event: .watermarkCompleted(layout: layout))
                self.asyncApply = AsyncOperation(status: .empty)
                self.onConfirm(newPdf)
                onCompletion()
            }
        }
    }
}
