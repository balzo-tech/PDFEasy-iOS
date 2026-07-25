//
//  PdfMarkdownImportViewModel.swift
//  PdfExpert
//
//  "Markdown to PDF": the text can be typed/pasted in the editor or loaded from a
//  .md/.txt file. Conversion is done by DocumentRenderUtility.convertMarkdown, which
//  deliberately avoids WebKit (Foundation parses the Markdown and the styled text is
//  paginated directly) — deterministic and fast, at the cost of tables and remote images.
//

import Foundation
import Factory
import SwiftUI
import UniformTypeIdentifiers

extension Container {
    var pdfMarkdownImportViewModel: ParameterFactory<PdfMarkdownImportViewModel.Params, PdfMarkdownImportViewModel> {
        self { PdfMarkdownImportViewModel(params: $0) }
    }
}

class PdfMarkdownImportViewModel: ObservableObject {

    struct Params {
        let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    }

    @Published var editorShow: Bool = false
    @Published var filePickerShow: Bool = false
    @Published var text: String = ""

    /// Nothing to convert until there is non-whitespace content.
    var canConvert: Bool {
        !self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Injected(\.analyticsManager) private var analyticsManager

    private let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    /// Set when the text came from a file, so the PDF keeps that name.
    private var importedFilename: String?

    init(params: Params) {
        self.asyncPdf = params.asyncPdf
    }

    @MainActor
    func start() {
        self.text = ""
        self.importedFilename = nil
        self.analyticsManager.track(event: .reportScreen(.markdownImport))
        self.editorShow = true
    }

    @MainActor
    func importFile() {
        self.filePickerShow = true
    }

    @MainActor
    func onFilePicked(_ url: URL?) {
        guard let url = url, let contents = try? String(contentsOf: url, encoding: .utf8) else {
            self.asyncPdf.wrappedValue = .init(status: .error(
                .underlyingError(errorDescription: String(localized: "This file could not be read as text."))
            ))
            return
        }
        self.text = contents
        self.importedFilename = url.filename
    }

    @MainActor
    func cancel() {
        self.editorShow = false
        self.text = ""
        self.importedFilename = nil
    }

    @MainActor
    func convert() {
        guard self.canConvert else { return }
        let markdown = self.text
        let filename = self.importedFilename
        self.editorShow = false

        // Defer so the editor finishes dismissing before the loader is presented on the
        // same hierarchy (same pattern as the other tools' sheet → loader handoff).
        DispatchQueue.main.async {
            self.asyncPdf.wrappedValue = .init(status: .loading(Progress.undeterminedProgress))
            do {
                let data = try DocumentRenderUtility.convertMarkdown(markdown)
                guard var pdf = Pdf(data: data) else {
                    throw DocumentRenderError.renderFailed
                }
                pdf.updateFilename(filename ?? String(localized: "Markdown document"))
                self.asyncPdf.wrappedValue = .init(status: .data(pdf))
                self.analyticsManager.track(event: .markdownToPdfCompleted)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? String(localized: "This text could not be converted.")
                self.asyncPdf.wrappedValue = .init(status: .error(.underlyingError(errorDescription: message)))
            }
            self.text = ""
            self.importedFilename = nil
        }
    }
}
