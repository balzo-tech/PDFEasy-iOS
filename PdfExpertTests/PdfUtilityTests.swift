//
//  PdfUtilityTests.swift
//  PdfExpertTests
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfUtilityTests: XCTestCase {

    /// Builds an in-memory PDF made of `pageCount` blank raster pages.
    private func makePdf(pageCount: Int) -> PDFDocument {
        let document = PDFDocument()
        let size = CGSize(width: 200, height: 300)
        for _ in 0..<pageCount {
            let image = UIGraphicsImageRenderer(size: size).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            if let page = PDFPage(image: image) {
                document.insert(page, at: document.pageCount)
            }
        }
        return document
    }

    /// The no-op path (no margins, no compression) returns an equivalent document
    /// and must not trap on the force-unwraps that used to live on that branch.
    func testApplyPostProcessNoOpPreservesPageCount() {
        let document = makePdf(pageCount: 3)
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .noMargins,
                                                 compression: .noCompression)
        XCTAssertEqual(result.pageCount, 3)
    }

    /// The processing path (margins + compression) must keep every page.
    func testApplyPostProcessWithMarginsKeepsPages() {
        let document = makePdf(pageCount: 2)
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .mediumMargins,
                                                 compression: .high)
        XCTAssertEqual(result.pageCount, 2)
    }

    /// An empty document must not crash: the `pageCount > 0` guard and the removed
    /// `dataRepresentation()!` force-unwrap are what this exercises. Reaching the
    /// assertion at all is the guarantee; PDFKit round-trips an empty document into
    /// a single blank page, so the page count is only loosely bounded here.
    func testApplyPostProcessEmptyDocumentDoesNotCrash() {
        let document = PDFDocument()
        let result = PDFUtility.applyPostProcess(toPdfDocument: document,
                                                 margins: .noMargins,
                                                 compression: .noCompression)
        XCTAssertLessThanOrEqual(result.pageCount, 1)
    }
}
