//
//  PdfExportUtilityTests.swift
//  PdfExpertTests
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfExportUtilityTests: XCTestCase {

    /// Files created by a test, deleted in tearDown so the temp dir stays clean.
    private var createdUrls: [URL] = []

    override func tearDown() {
        PdfExportUtility.cleanupExportFiles(self.createdUrls)
        self.createdUrls = []
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A PDF page with real, selectable (vector) text and no embedded images.
    private func makeTextPdf(text: String) -> Pdf {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            (text as NSString).draw(at: CGPoint(x: 50, y: 50),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        return Pdf(pdfDocument: PDFDocument(data: data) ?? PDFDocument())
    }

    /// A multi-page PDF where page i carries the text "PageContent-i".
    private func makeMultiPageTextPdf(pageCount: Int) -> Pdf {
        let document = PDFDocument()
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        for index in 0..<pageCount {
            let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
                context.beginPage()
                ("PageContent-\(index)" as NSString).draw(at: CGPoint(x: 50, y: 50),
                                                          withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
            if let pageDocument = PDFDocument(data: data), let page = pageDocument.page(at: 0) {
                document.insert(page, at: document.pageCount)
            }
        }
        return Pdf(pdfDocument: document)
    }

    /// A PDF built from a rasterized bitmap, so the page carries an embedded image XObject.
    private func makeBitmapPdf() -> Pdf {
        let size = CGSize(width: 400, height: 300)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 120, height: 90))
        }
        let bounds = CGRect(origin: .zero, size: size)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            image.draw(in: bounds)
        }
        return Pdf(pdfDocument: PDFDocument(data: data) ?? PDFDocument())
    }

    // MARK: - exportPageImages

    func testExportPageImagesPngReturnsFilePerPage() throws {
        let pdf = makeMultiPageTextPdf(pageCount: 3)
        let urls = try PdfExportUtility.exportPageImages(pdf: pdf, asPng: true)
        self.createdUrls += urls
        XCTAssertEqual(urls.count, 3)
        for url in urls {
            XCTAssertEqual(url.pathExtension, "png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "expected exported page image to exist at \(url.path)")
        }
    }

    func testExportPageImagesJpegReturnsFilePerPage() throws {
        let pdf = makeMultiPageTextPdf(pageCount: 2)
        let urls = try PdfExportUtility.exportPageImages(pdf: pdf, asPng: false)
        self.createdUrls += urls
        XCTAssertEqual(urls.count, 2)
        for url in urls {
            XCTAssertEqual(url.pathExtension, "jpg")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "expected exported page image to exist at \(url.path)")
        }
    }

    // MARK: - exportText

    func testExportTextWritesFixtureText() throws {
        let pdf = makeTextPdf(text: "Hello exportable world")
        let url = try PdfExportUtility.exportText(pdf: pdf)
        self.createdUrls.append(url)
        XCTAssertEqual(url.pathExtension, "txt")
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents.contains("exportable"),
                      "exported text file should contain the fixture text, got: \(contents)")
    }

    func testExportTextThrowsForImageOnlyDocument() {
        let pdf = makeBitmapPdf() // rasterized: no extractable text
        XCTAssertThrowsError(try PdfExportUtility.exportText(pdf: pdf)) { error in
            XCTAssertEqual(error as? PdfExportError, .noTextFound)
        }
    }

    // MARK: - exportEmbeddedImages

    func testExportEmbeddedImagesFindsImages() throws {
        let pdf = makeBitmapPdf()
        let urls = try PdfExportUtility.exportEmbeddedImages(pdf: pdf)
        self.createdUrls += urls
        XCTAssertGreaterThanOrEqual(urls.count, 1,
                                    "a PDF built from a bitmap must yield at least one embedded image")
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "expected exported embedded image to exist at \(url.path)")
        }
    }

    func testExportEmbeddedImagesThrowsForVectorTextOnlyDocument() {
        let pdf = makeTextPdf(text: "Only vector text here") // no embedded images
        XCTAssertThrowsError(try PdfExportUtility.exportEmbeddedImages(pdf: pdf)) { error in
            XCTAssertEqual(error as? PdfExportError, .noImagesFound)
        }
    }

    // MARK: - cleanup

    func testCleanupExportFilesRemovesFiles() throws {
        let pdf = makeMultiPageTextPdf(pageCount: 2)
        let urls = try PdfExportUtility.exportPageImages(pdf: pdf, asPng: true)
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
        PdfExportUtility.cleanupExportFiles(urls)
        for url in urls {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                           "cleanupExportFiles should remove \(url.path)")
        }
    }
}
