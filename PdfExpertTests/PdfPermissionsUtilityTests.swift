//
//  PdfPermissionsUtilityTests.swift
//  PdfExpertTests
//
//  PDFKit exposes the permission flags read-only, which is exactly what these tests
//  need: apply them through CGPDFContext, reopen the bytes, and check what a reader
//  would see.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfPermissionsUtilityTests: XCTestCase {

    private func makeTextPdf(text: String = "Permission test", pageCount: Int = 2) -> PDFDocument {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for pageIndex in 0..<pageCount {
                context.beginPage()
                ("\(text) \(pageIndex)" as NSString).draw(at: CGPoint(x: 40, y: 40),
                                                          withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    func testRestrictingPrintingAndCopyingIsVisibleToReaders() throws {
        let document = self.makeTextPdf()
        let data = try XCTUnwrap(PdfPermissionsUtility.apply(to: document,
                                                             ownerPassword: "owner-secret",
                                                             permissions: PdfPermissions(allowsPrinting: false,
                                                                                         allowsCopying: false)))
        let result = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertFalse(result.allowsPrinting)
        XCTAssertFalse(result.allowsCopying)
        XCTAssertTrue(result.isEncrypted)
        // No user password: the document must still open normally.
        XCTAssertFalse(result.isLocked)
    }

    func testAllowingEverythingKeepsBothPermissions() throws {
        let document = self.makeTextPdf()
        let data = try XCTUnwrap(PdfPermissionsUtility.apply(to: document,
                                                             ownerPassword: "owner-secret",
                                                             permissions: PdfPermissions()))
        let result = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertTrue(result.allowsPrinting)
        XCTAssertTrue(result.allowsCopying)
    }

    func testPagesAndTextSurviveTheReEmit() throws {
        let document = self.makeTextPdf(text: "Selectable", pageCount: 3)
        let data = try XCTUnwrap(PdfPermissionsUtility.apply(to: document,
                                                             ownerPassword: "owner",
                                                             permissions: PdfPermissions(allowsPrinting: false,
                                                                                         allowsCopying: true)))
        let result = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(result.pageCount, 3)
        XCTAssertTrue(PDFUtility.extractText(from: result).contains("Selectable"),
                      "drawPDFPage must copy content as-is, keeping text vector")
    }

    /// Without an owner password the flags would be ignored by every reader, so the
    /// utility refuses rather than writing a file that promises protection it lacks.
    func testMissingOwnerPasswordIsRejected() {
        let document = self.makeTextPdf()
        XCTAssertNil(PdfPermissionsUtility.apply(to: document,
                                                 ownerPassword: "",
                                                 permissions: PdfPermissions(allowsPrinting: false,
                                                                             allowsCopying: false)))
        XCTAssertNil(PdfPermissionsUtility.apply(to: document,
                                                 ownerPassword: "   ",
                                                 permissions: PdfPermissions()))
    }

    func testEmptyDocumentIsRejected() {
        XCTAssertNil(PdfPermissionsUtility.apply(to: PDFDocument(),
                                                 ownerPassword: "owner",
                                                 permissions: PdfPermissions()))
    }

    /// A user password additionally locks the document on open.
    func testUserPasswordLocksTheDocument() throws {
        let document = self.makeTextPdf()
        let data = try XCTUnwrap(PdfPermissionsUtility.apply(to: document,
                                                             ownerPassword: "owner",
                                                             userPassword: "reader",
                                                             permissions: PdfPermissions()))
        let result = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertTrue(result.isLocked)
        XCTAssertTrue(result.unlock(withPassword: "reader"))
    }

    /// A quarter-turned page must keep its landscape shape: /Rotate is not copied by
    /// `drawPDFPage`, so the rotation is baked into the output page box.
    func testRotatedPageKeepsItsOrientation() throws {
        let document = self.makeTextPdf(pageCount: 1)
        let page = try XCTUnwrap(document.page(at: 0))
        PDFUtility.rotatePage(page, clockwise: true)
        let rotatedDocument = try XCTUnwrap(document.dataRepresentation().flatMap { PDFDocument(data: $0) })

        let data = try XCTUnwrap(PdfPermissionsUtility.apply(to: rotatedDocument,
                                                             ownerPassword: "owner",
                                                             permissions: PdfPermissions()))
        let result = try XCTUnwrap(PDFDocument(data: data))
        let resultPage = try XCTUnwrap(result.page(at: 0))
        let size = resultPage.bounds(for: .mediaBox).size
        XCTAssertGreaterThan(size.width, size.height, "the rotated page should come out landscape")
    }
}
