//
//  AnnotationIdentityTests.swift
//  PdfExpertTests
//
//  Reported from the phone: a signature or a piece of text, once added, cannot be
//  edited any more.
//
//  The signature tool does not read every annotation on a page — it reads the ones
//  it recognises as its own, `isSignatureAnnotation`, which asks for a custom key
//  in the annotation's properties. Anything it does not recognise stays where it
//  is and cannot be picked up again. So the question is whether a signature this
//  app just made still looks like one to the app.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class AnnotationIdentityTests: XCTestCase {

    private func makeSignatureImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 200, height: 80)).image { context in
            UIColor.black.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 10, y: 60))
            path.addCurve(to: CGPoint(x: 190, y: 30),
                          controlPoint1: CGPoint(x: 60, y: 0),
                          controlPoint2: CGPoint(x: 140, y: 90))
            path.lineWidth = 4
            path.stroke()
        }
    }

    private func makeDocument() -> PDFDocument {
        let bounds = CGRect(origin: .zero, size: K.Misc.PdfPageSize)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.fill(bounds)
        }
        return PDFDocument(data: data)!
    }

    /// A signature the app has just made, on the page, in memory — which is the
    /// state the editor is in for every document that has not been saved yet.
    func testASignatureIsRecognisedAsSoonAsItIsMade() throws {
        let document = self.makeDocument()
        let page = try XCTUnwrap(document.page(at: 0))
        let signature = PDFAnnotation.createSignature(with: self.makeSignatureImage(),
                                                     forBounds: CGRect(x: 100, y: 100, width: 200, height: 80))
        page.addAnnotation(signature)

        let onThePage = try XCTUnwrap(page.annotations.first)
        print("KEYS in memory: \(onThePage.annotationKeyValues.keys.map { "\($0)" }.sorted())")

        XCTAssertTrue(onThePage.isSignatureAnnotation,
                      "the app does not recognise a signature it has just made, so the tool cannot offer it back for editing")
    }

    /// The same signature after the document has been through its own bytes,
    /// which is what saving does. If this passes while the test above fails, the
    /// difference is the round trip — and that is why a signature on a saved
    /// document can be edited while one on a new document cannot.
    func testASignatureIsStillRecognisedAfterSaving() throws {
        let document = self.makeDocument()
        let page = try XCTUnwrap(document.page(at: 0))
        page.addAnnotation(PDFAnnotation.createSignature(with: self.makeSignatureImage(),
                                                        forBounds: CGRect(x: 100, y: 100, width: 200, height: 80)))

        let data = try XCTUnwrap(document.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let reloadedPage = try XCTUnwrap(reloaded.page(at: 0))
        let annotation = try XCTUnwrap(reloadedPage.annotations.first, "the signature did not survive saving")
        print("KEYS after saving: \(annotation.annotationKeyValues.keys.map { "\($0)" }.sorted())")

        XCTAssertTrue(annotation.isSignatureAnnotation,
                      "a saved signature is not recognised either")
    }

    /// Text is recognised by its subtype alone, with no custom key involved, so it
    /// should survive both states. Here to tell the two reports apart: if this
    /// passes, "the text cannot be edited" is a different bug from the signature.
    func testTextIsRecognisedBeforeAndAfterSaving() throws {
        let document = self.makeDocument()
        let page = try XCTUnwrap(document.page(at: 0))
        let text = PDFAnnotation.create(with: "Hello",
                                        forBounds: CGRect(x: 80, y: 200, width: 200, height: 40),
                                        textColor: .black,
                                        fontName: "Helvetica",
                                        withProperties: nil)
        page.addAnnotation(text)

        XCTAssertTrue(try XCTUnwrap(page.annotations.first).isTextAnnotation,
                      "a text annotation is not recognised in memory")

        let data = try XCTUnwrap(document.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))
        let annotation = try XCTUnwrap(reloaded.page(at: 0)?.annotations.first)
        XCTAssertTrue(annotation.isTextAnnotation, "a text annotation is not recognised after saving")
    }
}
