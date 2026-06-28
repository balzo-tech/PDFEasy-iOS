//
//  OcrUtilityTests.swift
//  PdfExpertTests
//

import XCTest
import PDFKit
@testable import PdfExpert

final class OcrUtilityTests: XCTestCase {

    /// Builds an image-only PDF page: the text is rasterized into a bitmap first,
    /// so the resulting page has NO extractable text (it simulates a scan).
    private func makeScannedPdf(text: String) -> PDFDocument {
        let size = CGSize(width: 1000, height: 1400)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(
                in: CGRect(x: 80, y: 600, width: 840, height: 240),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 110),
                    .foregroundColor: UIColor.black
                ]
            )
        }
        let bounds = CGRect(origin: .zero, size: size)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            image.draw(in: bounds)
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    /// Builds a PDF page containing real, selectable (vector) text.
    private func makeTextPdf(text: String) -> PDFDocument {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            (text as NSString).draw(at: CGPoint(x: 50, y: 50),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    /// An image-only page must come out with a selectable, matching text layer.
    func testMakeSearchableAddsTextLayerToScannedPage() {
        let original = makeScannedPdf(text: "Searchable")
        XCTAssertTrue((original.page(at: 0)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      "fixture should be image-only (no extractable text)")

        let result = OcrUtility.makeSearchableDocument(from: original)
        let resultText = (result?.page(at: 0)?.string ?? "")

        XCTAssertFalse(resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "OCR must produce a selectable text layer")
        XCTAssertTrue(resultText.lowercased().contains("searchable"),
                      "recognized text should match the fixture, got: \(resultText)")
    }

    /// The page count must be preserved when OCR runs.
    func testMakeSearchablePreservesPageCount() {
        let result = OcrUtility.makeSearchableDocument(from: makeScannedPdf(text: "Hello"))
        XCTAssertEqual(result?.pageCount, 1)
    }

    /// A page that already has vector text must be left untouched (its text must
    /// survive and stay selectable — it must not be rasterized away).
    func testMakeSearchableKeepsExistingTextPage() {
        let document = makeTextPdf(text: "Already selectable text")
        XCTAssertTrue((document.page(at: 0)?.string ?? "").contains("selectable"),
                      "fixture should have extractable text")

        let result = OcrUtility.makeSearchableDocument(from: document)
        let resultText = (result?.page(at: 0)?.string ?? "")
        XCTAssertTrue(resultText.contains("selectable"),
                      "existing vector text must survive, got: \(resultText)")
        XCTAssertEqual(result?.pageCount, 1)
    }

    /// An empty document must not crash and must stay empty.
    func testMakeSearchableEmptyDocumentDoesNotCrash() {
        let result = OcrUtility.makeSearchableDocument(from: PDFDocument())
        XCTAssertEqual(result?.pageCount, 0)
    }

    /// JPEG compression of the page bitmap must not break the (vector) OCR text
    /// layer: the text stays selectable even at aggressive quality.
    func testMakeSearchableWithCompressionKeepsTextSelectable() {
        let result = OcrUtility.makeSearchableDocument(from: makeScannedPdf(text: "Searchable"),
                                                       jpegQuality: 0.3)
        let resultText = (result?.page(at: 0)?.string ?? "")
        XCTAssertTrue(resultText.lowercased().contains("searchable"),
                      "text must survive aggressive compression, got: \(resultText)")
    }

    /// A page with a compressible (smooth-gradient) background must come out
    /// smaller with JPEG compression than without it.
    func testMakeSearchableCompressionShrinksOutput() {
        let source = makeGradientScannedPdf(text: "Searchable")
        let uncompressed = OcrUtility.makeSearchableDocument(from: source, jpegQuality: 1.0)
        let compressed = OcrUtility.makeSearchableDocument(from: source, jpegQuality: 0.3)

        guard let uncompressedSize = uncompressed?.dataRepresentation()?.count,
              let compressedSize = compressed?.dataRepresentation()?.count else {
            return XCTFail("expected data for both documents")
        }
        XCTAssertLessThan(compressedSize, uncompressedSize,
                          "compressed (\(compressedSize)) should be smaller than uncompressed (\(uncompressedSize))")
    }

    /// Image-only page whose background is a smooth vertical gradient (cheap for
    /// JPEG, expensive for PNG), with large black text for the OCR to pick up.
    private func makeGradientScannedPdf(text: String) -> PDFDocument {
        let size = CGSize(width: 1500, height: 2000)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let colors = [UIColor.white.cgColor, UIColor(white: 0.45, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: .zero,
                                      end: CGPoint(x: 0, y: size.height),
                                      options: [])
            }
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: 360))
            (text as NSString).draw(
                in: CGRect(x: 100, y: 90, width: size.width - 200, height: 240),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 150),
                    .foregroundColor: UIColor.black
                ]
            )
        }
        let bounds = CGRect(origin: .zero, size: size)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            image.draw(in: bounds)
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }
}
