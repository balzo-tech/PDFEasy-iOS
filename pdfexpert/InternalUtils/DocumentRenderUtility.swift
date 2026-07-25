//
//  DocumentRenderUtility.swift
//  PdfExpert
//
//  On-device document → PDF rendering. Replaces PSPDFKit's `Processor.generatePDF`,
//  which could not ship: without a commercial license the SDK runs in a 1-hour demo
//  mode that is explicitly "not for redistribution", and its trial watermarks every
//  rendered PDF.
//
//  Engine: WebKit renders the document (iOS renders Office, iWork, RTF and HTML
//  natively), then `UIPrintPageRenderer` paginates it onto A4 pages.
//
//  Why the print formatter and NOT `WKWebView.createPDF(configuration:)`: createPDF
//  sizes the output on the *content*, so a long document comes back as a single
//  enormous page with no pagination. `viewPrintFormatter()` is the only API that
//  paginates properly. Text stays vector (WebKit draws glyphs through Core Graphics),
//  so the output remains selectable and searchable.
//
//  Fidelity caveat (documented, not fixable on-device): WebKit's Office rendering is
//  good for Word/RTF and weaker for complex spreadsheets and for docx headers, logos
//  and watermarks. That is exactly why `validateRenderedPdf` is strict — a document
//  WebKit cannot render usually yields a *blank* page rather than an error, and the
//  caller needs that signalled so it can offer the high-fidelity Stirling fallback.
//

import Foundation
import UIKit
import WebKit
import PDFKit
import UniformTypeIdentifiers

enum DocumentRenderError: LocalizedError, Equatable {
    /// The file extension is not one WebKit can render — do not even try.
    case unsupportedFormat
    /// WebKit failed to load the document, or pagination produced nothing.
    case renderFailed
    /// The load did not complete within the allotted time.
    case timeout
    /// A PDF was produced but every page is blank (typical of an unsupported layout).
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return String(localized: "This file type cannot be converted. Please try a different document.")
        case .renderFailed, .emptyOutput:
            return String(localized: "This document could not be converted on your device.")
        case .timeout:
            return String(localized: "The conversion took too long. Please try again with a smaller document.")
        }
    }
}

@MainActor
class DocumentRenderUtility {

    // MARK: - Layout

    /// A4 in points (72 dpi), matching `K.Misc.PdfPageSize` rounded to the exact ISO size.
    static let pageSize = CGSize(width: 595.2, height: 841.8)
    /// Margin applied to every side of the printable area.
    static let pageMargin: CGFloat = 20

    /// File extensions WebKit is known to render. Anything else short-circuits to
    /// `.unsupportedFormat` so the caller can go straight to the online fallback
    /// instead of burning a load + timeout on a document that cannot work.
    static let supportedFileExtensions: Set<String> = [
        "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "pages", "numbers", "key",
        "rtf", "rtfd", "txt", "html", "htm", "csv"
    ]

    static func canConvertFile(at url: URL) -> Bool {
        self.supportedFileExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Public entry points

    /// Office / iWork / RTF / HTML file → paginated A4 PDF data.
    static func convertFile(at url: URL,
                            timeout: TimeInterval = K.DocumentRender.FileTimeout) async throws -> Data {
        guard self.canConvertFile(at: url) else {
            throw DocumentRenderError.unsupportedFormat
        }
        let data = try await self.renderWithWebView(timeout: timeout) { webView in
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        try self.validateRenderedPdf(data)
        return data
    }

    /// Remote web page → paginated A4 PDF data.
    static func convertRemotePage(url: URL,
                                  timeout: TimeInterval = K.DocumentRender.WebPageTimeout) async throws -> Data {
        let data = try await self.renderWithWebView(timeout: timeout) { webView in
            webView.load(URLRequest(url: url))
        }
        try self.validateRenderedPdf(data)
        return data
    }

    /// Markdown text → paginated A4 PDF data.
    ///
    /// Deliberately does NOT go through WebKit: Foundation parses the Markdown and the
    /// styled text is paginated with `UISimpleTextPrintFormatter`. Faster, deterministic
    /// and unit-testable; the trade-off is no tables and no remote images.
    static func convertMarkdown(_ text: String) throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DocumentRenderError.emptyOutput }

        let attributed = MarkdownTextRenderer.attributedText(from: trimmed)
        guard attributed.length > 0 else { throw DocumentRenderError.emptyOutput }

        let formatter = UISimpleTextPrintFormatter(attributedText: attributed)
        let data = try self.paginate(printFormatter: formatter)
        try self.validateRenderedPdf(data)
        return data
    }

    // MARK: - WebKit rendering

    /// Loads content into an off-screen `WKWebView` and paginates it once loading
    /// settles. The web view is kept alive for the whole call (dropping it mid-load
    /// silently cancels the navigation).
    private static func renderWithWebView(timeout: TimeInterval,
                                          load: (WKWebView) -> Void) async throws -> Data {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(origin: .zero, size: Self.pageSize),
                                configuration: configuration)
        webView.isOpaque = true
        webView.backgroundColor = .white

        let coordinator = LoadCoordinator()
        webView.navigationDelegate = coordinator

        try await coordinator.waitForLoad(in: webView, timeout: timeout, load: load)

        // `viewPrintFormatter()` re-lays-out the document for print, so the web view
        // never needs to be in the view hierarchy.
        return try self.paginate(printFormatter: webView.viewPrintFormatter())
    }

    /// Drives a `UIPrintFormatter` through `UIPrintPageRenderer` and draws every page
    /// into a PDF context. `paperRect` / `printableRect` are read-only properties, so
    /// they are set via KVC — the documented way to configure a bare page renderer.
    private static func paginate(printFormatter: UIPrintFormatter) throws -> Data {
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

        let paperRect = CGRect(origin: .zero, size: Self.pageSize)
        let printableRect = paperRect.insetBy(dx: Self.pageMargin, dy: Self.pageMargin)
        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        // Reading `numberOfPages` is what triggers pagination.
        let pageCount = renderer.numberOfPages
        guard pageCount > 0 else { throw DocumentRenderError.renderFailed }

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: paperRect)
        let data = pdfRenderer.pdfData { context in
            for pageIndex in 0..<pageCount {
                context.beginPage()
                renderer.drawPage(at: pageIndex, in: paperRect)
            }
        }
        guard !data.isEmpty else { throw DocumentRenderError.renderFailed }
        return data
    }

    // MARK: - Output validation

    /// Rejects output that is technically a PDF but carries nothing: WebKit answers an
    /// unsupported layout with blank pages instead of an error, and shipping that to the
    /// user (rather than falling back) would be the worst possible outcome.
    static func validateRenderedPdf(_ data: Data) throws {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw DocumentRenderError.renderFailed
        }
        let hasContent = (0..<document.pageCount).contains { pageIndex in
            guard let page = document.page(at: pageIndex) else { return false }
            return !PDFUtility.pageIsBlank(page)
        }
        guard hasContent else { throw DocumentRenderError.emptyOutput }
    }
}

// MARK: - Load coordinator

/// Bridges `WKNavigationDelegate` callbacks to an `async` call, with a timeout.
/// The continuation is resumed exactly once — a double resume is a hard crash, so
/// every path goes through `finish(with:)`, which is a no-op after the first call.
private final class LoadCoordinator: NSObject, WKNavigationDelegate {

    /// Grace period after `didFinish` so WebKit can finish laying out the document
    /// before the print formatter measures it.
    private static let settleDelay: TimeInterval = 0.3

    private var continuation: CheckedContinuation<Void, Error>?
    private var timeoutWorkItem: DispatchWorkItem?

    func waitForLoad(in webView: WKWebView,
                     timeout: TimeInterval,
                     load: (WKWebView) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            let workItem = DispatchWorkItem { [weak self] in
                self?.finish(with: DocumentRenderError.timeout)
            }
            self.timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
            load(webView)
        }
    }

    private func finish(with error: Error?) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        self.timeoutWorkItem?.cancel()
        self.timeoutWorkItem = nil
        if let error = error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [weak self] in
            self?.finish(with: nil)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.finish(with: DocumentRenderError.renderFailed)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        self.finish(with: DocumentRenderError.renderFailed)
    }
}

// MARK: - Markdown → attributed text

/// Turns Markdown into printable attributed text. Foundation's parser produces runs
/// tagged with `PresentationIntent` but no line breaks and no fonts, so block
/// boundaries, list markers and typography are all rebuilt here.
enum MarkdownTextRenderer {

    static func attributedText(from markdown: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        // A parse failure here is not fatal: fall back to rendering the raw text.
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return NSAttributedString(string: markdown,
                                      attributes: [.font: UIFont.systemFont(ofSize: bodyFontSize)])
        }

        let result = NSMutableAttributedString()
        var previousBlockIdentity: Int?

        for run in parsed.runs {
            let intent = run.presentationIntent
            // `components` runs innermost-first, so the first one identifies the block
            // this run belongs to (paragraph, list item, header…).
            let blockIdentity = intent?.components.first?.identity

            if let previousBlockIdentity = previousBlockIdentity, blockIdentity != previousBlockIdentity {
                result.append(NSAttributedString(string: "\n\n"))
            }
            if blockIdentity != previousBlockIdentity, let marker = self.listMarker(for: intent) {
                result.append(NSAttributedString(string: marker,
                                                 attributes: [.font: UIFont.systemFont(ofSize: bodyFontSize)]))
            }
            previousBlockIdentity = blockIdentity

            let text = String(parsed[run.range].characters)
            guard !text.isEmpty else { continue }
            result.append(NSAttributedString(string: text,
                                             attributes: self.attributes(for: run.presentationIntent,
                                                                         inline: run.inlinePresentationIntent)))
        }

        return result
    }

    // MARK: Styling

    fileprivate static let bodyFontSize: CGFloat = 12

    private static func attributes(for intent: PresentationIntent?,
                                   inline: InlinePresentationIntent?) -> [NSAttributedString.Key: Any] {
        var font = UIFont.systemFont(ofSize: self.bodyFontSize)
        var color = UIColor.black

        for component in intent?.components ?? [] {
            switch component.kind {
            case .header(let level):
                font = UIFont.boldSystemFont(ofSize: self.headerFontSize(forLevel: level))
            case .codeBlock:
                font = UIFont.monospacedSystemFont(ofSize: self.bodyFontSize - 1, weight: .regular)
                color = .darkGray
            case .blockQuote:
                font = UIFont.italicSystemFont(ofSize: self.bodyFontSize)
                color = .darkGray
            default:
                break
            }
        }

        if let inline = inline {
            if inline.contains(.stronglyEmphasized) {
                font = UIFont.boldSystemFont(ofSize: font.pointSize)
            }
            if inline.contains(.emphasized) {
                font = UIFont.italicSystemFont(ofSize: font.pointSize)
            }
            if inline.contains(.code) {
                font = UIFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
            }
        }

        return [.font: font, .foregroundColor: color]
    }

    private static func headerFontSize(forLevel level: Int) -> CGFloat {
        switch level {
        case 1: return 24
        case 2: return 20
        case 3: return 17
        default: return 15
        }
    }

    /// `"• "` for bullets, `"3. "` for ordered items — the parser strips the source
    /// markers and only records the intent.
    private static func listMarker(for intent: PresentationIntent?) -> String? {
        guard let components = intent?.components else { return nil }
        var ordinal: Int?
        var isOrdered = false
        var isListItem = false

        for component in components {
            switch component.kind {
            case .listItem(let itemOrdinal):
                isListItem = true
                ordinal = itemOrdinal
            case .orderedList:
                isOrdered = true
            case .unorderedList:
                isOrdered = false
            default:
                break
            }
        }

        guard isListItem else { return nil }
        if isOrdered, let ordinal = ordinal {
            return "\(ordinal). "
        }
        return "• "
    }
}
