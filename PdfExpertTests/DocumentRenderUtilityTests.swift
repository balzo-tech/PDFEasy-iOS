//
//  DocumentRenderUtilityTests.swift
//  PdfExpertTests
//
//  Covers the on-device document → PDF engine that replaced PSPDFKit. The Markdown
//  path and the output validation are pure and fully asserted here; the WebKit path
//  is exercised with an HTML fixture (the real Office fidelity check stays a manual
//  on-device smoke test, since WebKit's Office rendering cannot be asserted offline).
//

import XCTest
import PDFKit
import UniformTypeIdentifiers
@testable import PdfExpert

@MainActor
final class DocumentRenderUtilityTests: XCTestCase {

    private var temporaryFiles: [URL] = []

    override func tearDown() {
        self.temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        self.temporaryFiles = []
        super.tearDown()
    }

    private func writeTemporaryFile(contents: String, extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("render-test-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        self.temporaryFiles.append(url)
        return url
    }

    // MARK: - Format gating

    func testCanConvertFileAcceptsOfficeAndIworkExtensions() {
        for ext in ["docx", "DOCX", "xlsx", "pptx", "pages", "rtf", "html"] {
            let url = URL(fileURLWithPath: "/tmp/file.\(ext)")
            XCTAssertTrue(DocumentRenderUtility.canConvertFile(at: url), "\(ext) should be supported")
        }
    }

    /// The picker has to offer what the engine can convert. It did not: `.word`
    /// listed `com.microsoft.word.doc` alone, which is Word 97 — every `.docx` in
    /// Files came up greyed out while `DocumentRenderUtility` was perfectly able to
    /// render it. The two lists are written apart, so this walks the file types the
    /// pickers promise and checks a real file of that kind would pass.
    func testPickerFileTypesCoverTheOfficeFormatsTheEngineRenders() {
        let cases: [(String, [UTType])] = [
            ("doc", ImportFileOption.word.fileTypes),
            ("docx", ImportFileOption.word.fileTypes),
            ("xls", ImportFileOption.excel.fileTypes),
            ("xlsx", ImportFileOption.excel.fileTypes),
            ("ppt", ImportFileOption.powerpoint.fileTypes),
            ("pptx", ImportFileOption.powerpoint.fileTypes),
            ("doc", ImportFileOption.allDocs.fileTypes),
            ("docx", ImportFileOption.allDocs.fileTypes),
            ("pages", ImportFileOption.allDocs.fileTypes),
            ("docx", K.Misc.ImportFileTypesForAddPage),
        ]
        for (ext, accepted) in cases {
            guard let type = UTType(filenameExtension: ext) else {
                XCTFail("no system type for .\(ext)")
                continue
            }
            XCTAssertTrue(accepted.contains { type.conforms(to: $0) },
                          ".\(ext) (\(type.identifier)) is not offered by that picker")
            XCTAssertTrue(DocumentRenderUtility.canConvertFile(at: URL(fileURLWithPath: "/tmp/f.\(ext)")),
                          ".\(ext) is offered but the engine would refuse it")
        }
    }

    func testCanConvertFileRejectsUnknownExtensions() {
        for ext in ["zip", "psd", "mp4", ""] {
            let url = URL(fileURLWithPath: "/tmp/file.\(ext)")
            XCTAssertFalse(DocumentRenderUtility.canConvertFile(at: url), "\(ext) should not be supported")
        }
    }

    /// An unsupported extension must fail immediately, without spending a WebKit load
    /// and its timeout — that is what makes the online fallback feel instant.
    func testConvertFileThrowsUnsupportedFormatWithoutLoading() async {
        let url = URL(fileURLWithPath: "/tmp/file.zip")
        do {
            _ = try await DocumentRenderUtility.convertFile(at: url)
            XCTFail("expected .unsupportedFormat")
        } catch let error as DocumentRenderError {
            XCTAssertEqual(error, .unsupportedFormat)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Markdown

    func testConvertMarkdownProducesSelectableText() throws {
        let data = try DocumentRenderUtility.convertMarkdown("# Title\n\nHello **markdown** world.")
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
        let text = PDFUtility.extractText(from: document)
        XCTAssertTrue(text.contains("Title"), "header text should survive, got: \(text)")
        XCTAssertTrue(text.contains("markdown"), "body text should survive, got: \(text)")
    }

    func testConvertMarkdownRendersListMarkers() throws {
        let data = try DocumentRenderUtility.convertMarkdown("- first item\n- second item")
        let document = try XCTUnwrap(PDFDocument(data: data))
        let text = PDFUtility.extractText(from: document)
        XCTAssertTrue(text.contains("first item"))
        XCTAssertTrue(text.contains("second item"))
        XCTAssertTrue(text.contains("•"), "unordered list items should get a bullet, got: \(text)")
    }

    func testConvertMarkdownOrderedListKeepsOrdinals() throws {
        let data = try DocumentRenderUtility.convertMarkdown("1. alpha\n2. beta")
        let document = try XCTUnwrap(PDFDocument(data: data))
        let text = PDFUtility.extractText(from: document)
        XCTAssertTrue(text.contains("1."), "ordered items should keep their ordinal, got: \(text)")
        XCTAssertTrue(text.contains("alpha"))
    }

    func testConvertMarkdownEmptyThrows() {
        for input in ["", "   \n  "] {
            XCTAssertThrowsError(try DocumentRenderUtility.convertMarkdown(input)) { error in
                XCTAssertEqual(error as? DocumentRenderError, .emptyOutput)
            }
        }
    }

    func testConvertMarkdownPaginatesLongContent() throws {
        let paragraph = String(repeating: "Lorem ipsum dolor sit amet. ", count: 40)
        let markdown = (0..<12).map { "## Section \($0)\n\n\(paragraph)" }.joined(separator: "\n\n")
        let data = try DocumentRenderUtility.convertMarkdown(markdown)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1, "long content must paginate, not overflow one page")
    }

    // MARK: - Output validation

    func testValidateRejectsInvalidData() {
        XCTAssertThrowsError(try DocumentRenderUtility.validateRenderedPdf(Data("not a pdf".utf8))) { error in
            XCTAssertEqual(error as? DocumentRenderError, .renderFailed)
        }
    }

    /// The crucial case: WebKit answers a document it cannot lay out with blank pages
    /// rather than an error, and shipping that instead of falling back would be worse
    /// than failing.
    func testValidateRejectsBlankPages() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            context.beginPage()
        }
        XCTAssertThrowsError(try DocumentRenderUtility.validateRenderedPdf(data)) { error in
            XCTAssertEqual(error as? DocumentRenderError, .emptyOutput)
        }
    }

    func testValidateAcceptsPageWithText() throws {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            ("Real content" as NSString).draw(at: CGPoint(x: 40, y: 40),
                                              withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        XCTAssertNoThrow(try DocumentRenderUtility.validateRenderedPdf(data))
    }

    /// A page carrying only graphics (no extractable text) is still real content.
    func testValidateAcceptsGraphicsOnlyPage() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(x: 50, y: 50, width: 300, height: 400))
        }
        XCTAssertNoThrow(try DocumentRenderUtility.validateRenderedPdf(data))
    }

    // MARK: - WebKit path

    func testConvertFileRendersHtmlIntoPaginatedPdf() async throws {
        let paragraph = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 30)
        let body = (0..<14).map { "<h2>Heading \($0)</h2><p>\(paragraph)</p>" }.joined()
        let url = try self.writeTemporaryFile(contents: "<html><body>\(body)</body></html>", extension: "html")

        let data = try await DocumentRenderUtility.convertFile(at: url)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1, "long HTML must span several A4 pages")
        XCTAssertTrue(PDFUtility.extractText(from: document).contains("quick brown fox"),
                      "rendered text must stay extractable (vector, not rasterized)")
    }
}
