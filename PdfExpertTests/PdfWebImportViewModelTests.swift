//
//  PdfWebImportViewModelTests.swift
//  PdfExpertTests
//
//  Covers the URL normalization that stands between what people type and what WebKit
//  is asked to load. The rendering itself is covered by DocumentRenderUtilityTests.
//

import XCTest
@testable import PdfExpert

final class PdfWebImportViewModelTests: XCTestCase {

    // MARK: - Normalization

    func testAddsHttpsWhenSchemeIsMissing() {
        let url = PdfWebImportViewModel.normalizedUrl(from: "balzo.eu")
        XCTAssertEqual(url?.absoluteString, "https://balzo.eu")
    }

    func testKeepsPathAndQuery() {
        let url = PdfWebImportViewModel.normalizedUrl(from: "www.balzo.eu/blog?page=2")
        XCTAssertEqual(url?.absoluteString, "https://www.balzo.eu/blog?page=2")
    }

    /// App Transport Security would block plain http anyway, so it is upgraded rather
    /// than failing on something the user cannot see.
    func testUpgradesHttpToHttps() {
        let url = PdfWebImportViewModel.normalizedUrl(from: "http://balzo.eu/page")
        XCTAssertEqual(url?.absoluteString, "https://balzo.eu/page")
    }

    func testAcceptsExistingHttpsUntouched() {
        let url = PdfWebImportViewModel.normalizedUrl(from: "  https://balzo.eu  ")
        XCTAssertEqual(url?.absoluteString, "https://balzo.eu")
    }

    func testRejectsEmptyAndHostlessInput() {
        XCTAssertNil(PdfWebImportViewModel.normalizedUrl(from: ""))
        XCTAssertNil(PdfWebImportViewModel.normalizedUrl(from: "   "))
        // No dot in the host: not an address, and it must not reach the network.
        XCTAssertNil(PdfWebImportViewModel.normalizedUrl(from: "localhost"))
        XCTAssertNil(PdfWebImportViewModel.normalizedUrl(from: "just some text"))
    }

    func testRejectsMalformedHost() {
        XCTAssertNil(PdfWebImportViewModel.normalizedUrl(from: ".eu"))
        XCTAssertNil(PdfWebImportViewModel.normalizedUrl(from: "balzo."))
    }

    // MARK: - Filename

    func testFilenameDropsWwwPrefix() {
        let url = URL(string: "https://www.balzo.eu/blog")!
        XCTAssertEqual(PdfWebImportViewModel.filename(for: url), "balzo.eu")
    }

    func testFilenameUsesHost() {
        let url = URL(string: "https://docs.stirlingpdf.com/API")!
        XCTAssertEqual(PdfWebImportViewModel.filename(for: url), "docs.stirlingpdf.com")
    }
}
