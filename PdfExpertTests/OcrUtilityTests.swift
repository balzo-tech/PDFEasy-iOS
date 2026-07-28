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
        let resultText = (result?.document.page(at: 0)?.string ?? "")

        XCTAssertFalse(resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "OCR must produce a selectable text layer")
        XCTAssertTrue(resultText.lowercased().contains("searchable"),
                      "recognized text should match the fixture, got: \(resultText)")
    }

    /// The page count must be preserved when OCR runs.
    func testMakeSearchablePreservesPageCount() {
        let result = OcrUtility.makeSearchableDocument(from: makeScannedPdf(text: "Hello"))
        XCTAssertEqual(result?.document.pageCount, 1)
    }

    /// A page that already has vector text must be left untouched (its text must
    /// survive and stay selectable — it must not be rasterized away).
    func testMakeSearchableKeepsExistingTextPage() {
        let document = makeTextPdf(text: "Already selectable text")
        XCTAssertTrue((document.page(at: 0)?.string ?? "").contains("selectable"),
                      "fixture should have extractable text")

        let result = OcrUtility.makeSearchableDocument(from: document)
        let resultText = (result?.document.page(at: 0)?.string ?? "")
        XCTAssertTrue(resultText.contains("selectable"),
                      "existing vector text must survive, got: \(resultText)")
        XCTAssertEqual(result?.document.pageCount, 1)
    }

    /// An empty document must not crash and must stay empty.
    func testMakeSearchableEmptyDocumentDoesNotCrash() {
        let result = OcrUtility.makeSearchableDocument(from: PDFDocument())
        XCTAssertEqual(result?.document.pageCount, 0)
        XCTAssertEqual(result?.didChangeDocument, false)
        XCTAssertEqual(result?.wasAlreadySearchable, false,
                       "an empty document has nothing to be already searchable")
    }

    /// JPEG compression of the page bitmap must not break the (vector) OCR text
    /// layer: the text stays selectable even at the harshest preset.
    func testMakeSearchableWithCompressionKeepsTextSelectable() {
        let result = OcrUtility.makeSearchableDocument(from: makeScannedPdf(text: "Searchable"),
                                                       preset: .maximum)
        let resultText = (result?.document.page(at: 0)?.string ?? "")
        XCTAssertTrue(resultText.lowercased().contains("searchable"),
                      "text must survive aggressive compression, got: \(resultText)")
    }

    /// A page with a compressible (smooth-gradient) background must come out
    /// smaller under a harsher preset than under a light one.
    func testMakeSearchableCompressionShrinksOutput() {
        let source = makeGradientScannedPdf(text: "Searchable")
        let light = OcrUtility.makeSearchableDocument(from: source, preset: .light)
        let maximum = OcrUtility.makeSearchableDocument(from: source, preset: .maximum)

        guard let lightSize = light?.document.dataRepresentation()?.count,
              let maximumSize = maximum?.document.dataRepresentation()?.count else {
            return XCTFail("expected data for both documents")
        }
        XCTAssertLessThan(maximumSize, lightSize,
                          ".maximum (\(maximumSize)) should be smaller than .light (\(lightSize))")
    }

    // MARK: - What the run reports back

    /// A scan must be reported as OCR'd, not as anything else.
    func testResultCountsOcredPage() {
        let result = OcrUtility.makeSearchableDocument(from: makeScannedPdf(text: "Searchable"))
        XCTAssertEqual(result?.ocredPageCount, 1)
        XCTAssertEqual(result?.alreadySearchablePageCount, 0)
        XCTAssertEqual(result?.unrecognizedPageCount, 0)
        XCTAssertEqual(result?.didChangeDocument, true)
        XCTAssertEqual(result?.wasAlreadySearchable, false)
    }

    /// A document that is already searchable must say so, and must come back
    /// unchanged — the case that used to be silent.
    func testResultReportsAlreadySearchableDocument() {
        let result = OcrUtility.makeSearchableDocument(from: makeTextPdf(text: "Already selectable text"))
        XCTAssertEqual(result?.alreadySearchablePageCount, 1)
        XCTAssertEqual(result?.ocredPageCount, 0)
        XCTAssertEqual(result?.didChangeDocument, false,
                       "nothing was OCR'd, so the document must not be marked as changed")
        XCTAssertEqual(result?.wasAlreadySearchable, true)
    }

    /// An image-only page with nothing to recognize is neither OCR'd nor already
    /// searchable: it has to be told apart from both.
    func testResultReportsUnrecognizedPage() {
        let result = OcrUtility.makeSearchableDocument(from: makeBlankScannedPdf())
        XCTAssertEqual(result?.unrecognizedPageCount, 1)
        XCTAssertEqual(result?.ocredPageCount, 0)
        XCTAssertEqual(result?.alreadySearchablePageCount, 0)
        XCTAssertEqual(result?.didChangeDocument, false)
        XCTAssertEqual(result?.wasAlreadySearchable, false,
                       "a page Vision read nothing on is not an already-searchable page")
    }

    /// A mixed document must count each page as what it is.
    func testResultCountsMixedDocument() {
        let mixed = makeScannedPdf(text: "Searchable")
        if let textPage = makeTextPdf(text: "Already selectable text").page(at: 0) {
            mixed.insert(textPage, at: mixed.pageCount)
        }
        let result = OcrUtility.makeSearchableDocument(from: mixed)
        XCTAssertEqual(result?.document.pageCount, 2)
        XCTAssertEqual(result?.ocredPageCount, 1)
        XCTAssertEqual(result?.alreadySearchablePageCount, 1)
        XCTAssertEqual(result?.didChangeDocument, true)
        XCTAssertEqual(result?.wasAlreadySearchable, false,
                       "one page still needed OCR, so the document was not already searchable")
    }

    /// An image-only page with no text on it at all (a blank scan).
    private func makeBlankScannedPdf() -> PDFDocument {
        let size = CGSize(width: 600, height: 800)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let bounds = CGRect(origin: .zero, size: size)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            image.draw(in: bounds)
        }
        return PDFDocument(data: data) ?? PDFDocument()
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
