//
//  PdfWatermarkViewModel.swift
//  PdfExpert
//
//  Premium tool that stamps a text watermark across every page of a PDF. Wraps
//  `PdfOverlayUtility.addWatermark`, running the redraw off the main thread and
//  publishing an `AsyncOperation` so the view can show a loader.
//
//  The watermark goes on a **copy**, saved straight to the archive, and the source
//  document is left alone — the same trade Compress and Redact make. It is not a
//  precaution: the overlay is drawn into the page content rather than laid on top
//  as an annotation (that is what keeps the text selectable), so there is nothing
//  to remove afterwards. Overwriting the original would make "put a watermark on
//  it to send it" a one-way door.
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
        /// Called once the copy is in the archive, so the host can say so over the
        /// document rather than over a screen that is on its way out.
        let onSaved: () -> Void
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
    @Injected(\.repository) private var repository

    private let pdf: Pdf
    private let onSaved: () -> Void

    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        self.onSaved = inputParameter.onSaved
    }

    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.watermark))
    }

    /// Applies the watermark on a background queue and saves the result as a new
    /// document. `onCompletion` lets the view dismiss itself once the copy is filed.
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
                // A *new* `Pdf`, not a mutated copy of the source: `Pdf` carries the
                // Core Data storeId, so saving a mutated one would overwrite the
                // clean original — and the original is the only way back from a
                // watermark, which cannot be lifted off the page once drawn.
                var watermarkedPdf = Pdf(pdfDocument: newDocument)
                watermarkedPdf.updateFilename(sourcePdf.filename + "-watermarked")
                do {
                    _ = try self.repository.savePdf(pdf: watermarkedPdf)
                } catch {
                    self.asyncApply = AsyncOperation(status: .error(.unknownError))
                    return
                }
                self.analyticsManager.track(event: .watermarkCompleted(layout: layout))
                self.asyncApply = AsyncOperation(status: .empty)
                self.onSaved()
                onCompletion()
            }
        }
    }
}
