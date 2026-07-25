//
//  PdfAnnotationTests.swift
//  PdfExpertTests
//
//  The reader's markup is only useful if it survives being written to the archive and
//  read back, so that round-trip is what these tests pin down. Creating the annotations
//  from a text selection needs a live PDFView and stays a manual smoke test.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfAnnotationTests: XCTestCase {

    private func makeTextPdf(text: String = "Annotate me") -> PDFDocument {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            (text as NSString).draw(at: CGPoint(x: 40, y: 40),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    func testAnnotationTypesMapToPdfKitSubtypes() {
        XCTAssertEqual(PdfAnnotationType.highlight.subtype, .highlight)
        XCTAssertEqual(PdfAnnotationType.underline.subtype, .underline)
        XCTAssertEqual(PdfAnnotationType.strikethrough.subtype, .strikeOut)
    }

    func testMarkupSurvivesTheDocumentRoundTrip() throws {
        let document = self.makeTextPdf()
        let page = try XCTUnwrap(document.page(at: 0))
        let bounds = CGRect(x: 40, y: 520, width: 200, height: 30)

        let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        annotation.color = .yellow
        page.addAnnotation(annotation)

        let data = try XCTUnwrap(document.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let reloadedPage = try XCTUnwrap(reloaded.page(at: 0))

        XCTAssertEqual(reloadedPage.annotations.count, 1)
        let reloadedAnnotation = try XCTUnwrap(reloadedPage.annotations.first)
        XCTAssertEqual(reloadedAnnotation.type, PDFAnnotationSubtype.highlight.rawValue.replacingOccurrences(of: "/", with: ""))
        XCTAssertEqual(reloadedAnnotation.bounds, bounds)
    }

    func testAllMarkupTypesSurviveTheRoundTrip() throws {
        let document = self.makeTextPdf()
        let page = try XCTUnwrap(document.page(at: 0))
        for (index, type) in PdfAnnotationType.allCases.enumerated() {
            let annotation = PDFAnnotation(bounds: CGRect(x: 40, y: 100 + 40 * index, width: 150, height: 24),
                                           forType: type.subtype,
                                           withProperties: nil)
            annotation.color = .green
            page.addAnnotation(annotation)
        }

        let data = try XCTUnwrap(document.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(reloaded.page(at: 0)?.annotations.count, PdfAnnotationType.allCases.count)
    }

    /// Markup must not cost the document its selectable text.
    func testTextStaysExtractableAfterAnnotating() throws {
        let document = self.makeTextPdf(text: "Still selectable")
        let page = try XCTUnwrap(document.page(at: 0))
        page.addAnnotation(PDFAnnotation(bounds: CGRect(x: 40, y: 520, width: 200, height: 30),
                                         forType: .highlight,
                                         withProperties: nil))

        let data = try XCTUnwrap(document.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertTrue(PDFUtility.extractText(from: reloaded).contains("Still selectable"))
    }

    /// Flatten is the documented counterpart: it bakes markup into the page, which is
    /// why annotating should be the last step in a workflow.
    func testFlattenRemovesMarkupButKeepsItVisible() throws {
        let document = self.makeTextPdf(text: "Body")
        let page = try XCTUnwrap(document.page(at: 0))
        let annotation = PDFAnnotation(bounds: CGRect(x: 40, y: 520, width: 200, height: 30),
                                       forType: .highlight,
                                       withProperties: nil)
        annotation.color = .yellow
        page.addAnnotation(annotation)

        let flattened = try XCTUnwrap(PdfCleanupUtility.flatten(document))
        XCTAssertTrue(flattened.page(at: 0)?.annotations.isEmpty ?? false)
        XCTAssertTrue(PDFUtility.extractText(from: flattened).contains("Body"))
    }
}
