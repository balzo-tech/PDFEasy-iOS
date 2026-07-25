//
//  PdfRedactUtilityTests.swift
//  PdfExpertTests
//
//  The assertion that matters: after redacting, the covered text is *gone from the
//  file*, not merely hidden. A black rectangle drawn over live text (or a black
//  annotation) would pass a visual check and still hand the words to anyone who
//  extracts or copies them.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfRedactUtilityTests: XCTestCase {

    private static let pageBounds = CGRect(x: 0, y: 0, width: 400, height: 600)

    private func makeDocument(pageTexts: [String]) -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: Self.pageBounds).pdfData { context in
            for text in pageTexts {
                context.beginPage()
                (text as NSString).draw(at: CGPoint(x: 40, y: 40),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    /// Average brightness (0…1) of a page area given in normalized, top-left coordinates.
    private func brightness(of page: PDFPage, normalizedRect: CGRect) -> CGFloat {
        let pageSize = page.bounds(for: .mediaBox).size
        let image = page.thumbnail(of: pageSize, for: .mediaBox)
        guard let cgImage = image.cgImage else { return 1 }

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 255, count: width * height)
        guard let context = CGContext(data: &pixels,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return 1 }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let minX = Int(normalizedRect.minX * CGFloat(width))
        let maxX = Int(normalizedRect.maxX * CGFloat(width))
        let minY = Int(normalizedRect.minY * CGFloat(height))
        let maxY = Int(normalizedRect.maxY * CGFloat(height))
        guard minX < maxX, minY < maxY else { return 1 }

        var total = 0
        var count = 0
        for y in minY..<min(maxY, height) {
            for x in minX..<min(maxX, width) {
                total += Int(pixels[y * width + x])
                count += 1
            }
        }
        return count > 0 ? CGFloat(total) / CGFloat(count) / 255.0 : 1
    }

    // MARK: - Text removal

    func testRedactedPageLosesItsText() throws {
        let document = self.makeDocument(pageTexts: ["Secret payload", "Public page"])
        let box = RedactionBox(pageIndex: 0, rect: CGRect(x: 0.05, y: 0.05, width: 0.6, height: 0.2))

        let redacted = try XCTUnwrap(PdfRedactUtility.redact(document: document, boxes: [box]))
        let redactedText = redacted.page(at: 0)?.string ?? ""
        XCTAssertFalse(redactedText.contains("Secret"),
                       "the redacted page must no longer expose its text, got: \(redactedText)")
    }

    /// Only the marked pages pay the price: everything else keeps its selectable text.
    func testUntouchedPagesKeepTheirText() throws {
        let document = self.makeDocument(pageTexts: ["Secret payload", "Public page"])
        let box = RedactionBox(pageIndex: 0, rect: CGRect(x: 0.05, y: 0.05, width: 0.6, height: 0.2))

        let redacted = try XCTUnwrap(PdfRedactUtility.redact(document: document, boxes: [box]))
        XCTAssertTrue((redacted.page(at: 1)?.string ?? "").contains("Public"),
                      "pages without boxes must stay untouched and selectable")
    }

    func testPageCountIsPreserved() throws {
        let document = self.makeDocument(pageTexts: ["One", "Two", "Three"])
        let box = RedactionBox(pageIndex: 1, rect: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.3))
        let redacted = try XCTUnwrap(PdfRedactUtility.redact(document: document, boxes: [box]))
        XCTAssertEqual(redacted.pageCount, 3)
    }

    func testSourceDocumentIsNotMutated() throws {
        let document = self.makeDocument(pageTexts: ["Secret payload"])
        let box = RedactionBox(pageIndex: 0, rect: CGRect(x: 0, y: 0, width: 1, height: 1))
        _ = PdfRedactUtility.redact(document: document, boxes: [box])
        XCTAssertTrue((document.page(at: 0)?.string ?? "").contains("Secret"),
                      "the input document must be left alone")
    }

    func testNoBoxesReturnsTheInput() throws {
        let document = self.makeDocument(pageTexts: ["Untouched"])
        let result = try XCTUnwrap(PdfRedactUtility.redact(document: document, boxes: []))
        XCTAssertTrue((result.page(at: 0)?.string ?? "").contains("Untouched"))
    }

    // MARK: - Geometry

    /// The box must land where the user drew it, and nowhere else.
    func testBoxIsBlackAndTheRestIsNot() throws {
        let document = self.makeDocument(pageTexts: [" "])
        let boxRect = CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2)
        let redacted = try XCTUnwrap(PdfRedactUtility.redact(document: document,
                                                             boxes: [RedactionBox(pageIndex: 0, rect: boxRect)]))
        let page = try XCTUnwrap(redacted.page(at: 0))

        // Sample the middle of the box, and a clearly separate area.
        let insideSample = CGRect(x: 0.2, y: 0.15, width: 0.05, height: 0.05)
        let outsideSample = CGRect(x: 0.7, y: 0.7, width: 0.1, height: 0.1)
        XCTAssertLessThan(self.brightness(of: page, normalizedRect: insideSample), 0.2,
                          "the redacted area should be black")
        XCTAssertGreaterThan(self.brightness(of: page, normalizedRect: outsideSample), 0.8,
                             "areas outside the box must be left alone")
    }

    func testRectForBoxScalesToPageSize() {
        let box = RedactionBox(pageIndex: 0, rect: CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25))
        let rect = PdfRedactUtility.rect(for: box, pageSize: CGSize(width: 400, height: 600))
        XCTAssertEqual(rect, CGRect(x: 100, y: 300, width: 200, height: 150))
    }

    /// A rotated page renders landscape; the box must follow the displayed geometry,
    /// which is the space the UI measured it in.
    func testRotatedPageKeepsBoxPlacement() throws {
        let document = self.makeDocument(pageTexts: [" "])
        let page = try XCTUnwrap(document.page(at: 0))
        PDFUtility.rotatePage(page, clockwise: true)
        let rotated = try XCTUnwrap(document.dataRepresentation().flatMap { PDFDocument(data: $0) })

        let boxRect = CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2)
        let redacted = try XCTUnwrap(PdfRedactUtility.redact(document: rotated,
                                                             boxes: [RedactionBox(pageIndex: 0, rect: boxRect)]))
        let redactedPage = try XCTUnwrap(redacted.page(at: 0))
        let size = redactedPage.bounds(for: .mediaBox).size
        XCTAssertGreaterThan(size.width, size.height, "the rasterized page should stay landscape")
        XCTAssertLessThan(self.brightness(of: redactedPage,
                                          normalizedRect: CGRect(x: 0.2, y: 0.15, width: 0.05, height: 0.05)),
                          0.2)
    }
}
