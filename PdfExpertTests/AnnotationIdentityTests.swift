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

    /// Both annotation tools detach every annotation from its page on the way in —
    /// the page is rendered as a flat image and the annotations are held in an
    /// array, so they can be drawn as editable boxes on top. Afterwards they find
    /// them again by asking `annotation.page`:
    ///
    ///     let textAnnotationsInPoint = textAnnotations.filter { $0.page == page && … }
    ///     let pageAnnotations = self.annotations.filter { $0.page == page }
    ///
    /// If removing an annotation from a page clears that reference, neither filter
    /// can ever match — you could not tap an existing signature to edit it, and
    /// the confirm step could not put anything back. Which is it?
    func testAnAnnotationRemembersItsPageAfterBeingDetached() throws {
        let document = self.makeDocument()
        let page = try XCTUnwrap(document.page(at: 0))
        let signature = PDFAnnotation.createSignature(with: self.makeSignatureImage(),
                                                     forBounds: CGRect(x: 100, y: 100, width: 200, height: 80))
        page.addAnnotation(signature)
        XCTAssertTrue(signature.page === page, "an annotation on a page should know its page")

        // Measured: it forgets. This is PDFKit's behaviour, not a bug in the app —
        // but it is the reason a saved signature could not be edited, because both
        // tools detached first and matched on `page` afterwards.
        page.removeAnnotation(signature)
        XCTAssertNil(signature.page, "PDFKit used to clear this; if it stops, the workaround below can go")

        // What the view models do now, and the only thing that makes the filters
        // work: give the page back after detaching.
        signature.page = page
        XCTAssertTrue(signature.page === page)
        XCTAssertFalse(page.annotations.contains(signature),
                       "the annotation must stay off the page — it is drawn as an editable box instead")
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

// MARK: - Tapping the page in the editor

/// The editor's pager shows an *image* of the page, not a `PDFView`, so there is
/// no `convert(_:to:)` to lean on: `PdfEditViewModel.pointInPage` does the
/// arithmetic. It has two chances to be wrong in ways nobody would notice —
/// the letterbox of an aspect-fit image, and PDF space having its origin at the
/// bottom — and being wrong means tapping an element does nothing.
final class EditorPageHitTestingTests: XCTestCase {

    private func makePage(size: CGSize = CGSize(width: 600, height: 800)) throws -> PDFPage {
        let bounds = CGRect(origin: .zero, size: size)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
        }
        return try XCTUnwrap(PDFDocument(data: data)?.page(at: 0))
    }

    func testTheCentreOfTheViewIsTheCentreOfThePage() throws {
        let page = try self.makePage()
        let viewSize = CGSize(width: 300, height: 700)
        let point = try XCTUnwrap(PdfEditViewModel.pointInPage(CGPoint(x: 150, y: 350),
                                                              viewSize: viewSize,
                                                              page: page))
        let mediaBox = page.bounds(for: .mediaBox)
        XCTAssertEqual(point.x, mediaBox.midX, accuracy: 1)
        XCTAssertEqual(point.y, mediaBox.midY, accuracy: 1)
    }

    /// The one that catches a flipped axis: a tap near the top of the screen has
    /// to land near the *top* of the page, which in PDF coordinates is the high y.
    func testATapNearTheTopLandsNearTheTopOfThePage() throws {
        let page = try self.makePage()
        // A view the same shape as the page, so there is no letterbox to reason
        // about and only the direction of y is under test.
        let viewSize = CGSize(width: 300, height: 400)
        let near = try XCTUnwrap(PdfEditViewModel.pointInPage(CGPoint(x: 150, y: 20),
                                                             viewSize: viewSize,
                                                             page: page))
        XCTAssertGreaterThan(near.y, page.bounds(for: .mediaBox).midY,
                             "a tap at the top of the view mapped to the bottom of the page")
    }

    /// An aspect-fit image in a wider view is letterboxed left and right, and a
    /// tap in the bars is not a tap on the page.
    func testATapInTheLetterboxIsNotOnThePage() throws {
        let page = try self.makePage()
        let viewSize = CGSize(width: 1000, height: 400)
        XCTAssertNil(PdfEditViewModel.pointInPage(CGPoint(x: 5, y: 200),
                                                  viewSize: viewSize,
                                                  page: page),
                     "a tap beside the page was reported as being on it")
        XCTAssertNotNil(PdfEditViewModel.pointInPage(CGPoint(x: 500, y: 200),
                                                     viewSize: viewSize,
                                                     page: page))
    }

    /// The corners, which is where an off-by-one in the letterbox shows up.
    func testTheCornersMapToTheCornersOfThePage() throws {
        let page = try self.makePage()
        let viewSize = CGSize(width: 300, height: 400)
        let mediaBox = page.bounds(for: .mediaBox)

        let topLeft = try XCTUnwrap(PdfEditViewModel.pointInPage(CGPoint(x: 0.5, y: 0.5),
                                                                viewSize: viewSize, page: page))
        XCTAssertEqual(topLeft.x, mediaBox.minX, accuracy: 2)
        XCTAssertEqual(topLeft.y, mediaBox.maxY, accuracy: 2)

        let bottomRight = try XCTUnwrap(PdfEditViewModel.pointInPage(CGPoint(x: viewSize.width - 0.5,
                                                                            y: viewSize.height - 0.5),
                                                                    viewSize: viewSize, page: page))
        XCTAssertEqual(bottomRight.x, mediaBox.maxX, accuracy: 2)
        XCTAssertEqual(bottomRight.y, mediaBox.minY, accuracy: 2)
    }
}
