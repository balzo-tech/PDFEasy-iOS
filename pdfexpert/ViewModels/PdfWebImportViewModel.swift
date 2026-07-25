//
//  PdfWebImportViewModel.swift
//  PdfExpert
//
//  "Web page to PDF": renders a remote page on-device (WebKit + A4 pagination, see
//  DocumentRenderUtility) and hands the result to the host's async channel, so the
//  editor opens exactly as it does for any other import.
//
//  Known limits, by design: cookie banners and paywalls are captured as they render,
//  and pages behind a login are unreachable (the web view carries no Safari session).
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfWebImportViewModel: ParameterFactory<PdfWebImportViewModel.Params, PdfWebImportViewModel> {
        self { PdfWebImportViewModel(params: $0) }
    }
}

class PdfWebImportViewModel: ObservableObject {

    struct Params {
        let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>
    }

    @Published var urlInputShow: Bool = false

    @Injected(\.analyticsManager) private var analyticsManager

    private let asyncPdf: Binding<AsyncOperation<Pdf, PdfError>>

    init(params: Params) {
        self.asyncPdf = params.asyncPdf
    }

    @MainActor
    func start() {
        self.analyticsManager.track(event: .reportScreen(.webImport))
        self.urlInputShow = true
    }

    @MainActor
    func convert(urlText: String) {
        guard let url = Self.normalizedUrl(from: urlText) else {
            self.asyncPdf.wrappedValue = .init(status: .error(
                .underlyingError(errorDescription: String(localized: "This web address is not valid. Please check it and try again."))
            ))
            return
        }

        self.analyticsManager.track(event: .webToPdfStarted)
        self.asyncPdf.wrappedValue = .init(status: .loading(Progress.undeterminedProgress))
        Task { @MainActor in
            do {
                let data = try await DocumentRenderUtility.convertRemotePage(url: url)
                guard var pdf = Pdf(data: data) else {
                    throw DocumentRenderError.renderFailed
                }
                pdf.updateFilename(Self.filename(for: url))
                self.asyncPdf.wrappedValue = .init(status: .data(pdf))
                self.analyticsManager.track(event: .webToPdfCompleted)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? String(localized: "This page could not be converted. Please try a different address.")
                self.asyncPdf.wrappedValue = .init(status: .error(.underlyingError(errorDescription: message)))
            }
        }
    }

    // MARK: - Pure helpers (unit-tested)

    /// Accepts what people actually type ("balzo.eu", "www.balzo.eu/page"). A missing
    /// scheme becomes **https**, and a plain `http://` is upgraded too — App Transport
    /// Security would block it anyway, and failing on a technicality the user cannot
    /// see would be worse than silently using the secure scheme.
    static func normalizedUrl(from text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("http://") {
            trimmed = "https://" + trimmed.dropFirst("http://".count)
        } else if !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }

        guard let url = URL(string: trimmed),
              let host = url.host,
              host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix(".") else { return nil }
        return url
    }

    /// Filename for the archived document: the host without `www.`, so a saved page is
    /// recognizable in the archive list.
    static func filename(for url: URL) -> String {
        guard let host = url.host else { return "web-page" }
        let cleaned = host.hasPrefix("www.") ? String(host.dropFirst("www.".count)) : host
        return cleaned.isEmpty ? "web-page" : cleaned
    }
}
