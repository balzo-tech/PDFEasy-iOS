//
//  PdfTitleUtilityTests.swift
//  PdfExpertTests
//
//  Covers what the editor proposes as a document's name. Two things matter here and
//  both are asserted: that a real title is found (metadata first, then the largest
//  type on the first page), and — more important — that junk is rejected, because a
//  wrong suggestion in the title field costs the user more than no suggestion.
//
//  The second class covers when the editor offers it at all — the gate that keeps a
//  suggestion away from a document somebody has already named.
//

import XCTest
import SwiftUI
import Factory
import PDFKit
@testable import PdfExpert

final class PdfTitleUtilityTests: XCTestCase {

    // MARK: - Fixtures

    private static let pageBounds = CGRect(x: 0, y: 0, width: 400, height: 600)

    /// A page of `(text, font size)` lines, drawn top to bottom.
    private func makeDocument(lines: [(String, CGFloat)], title: String? = nil) -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: Self.pageBounds).pdfData { context in
            context.beginPage()
            var y: CGFloat = 40
            for (text, size) in lines {
                (text as NSString).draw(at: CGPoint(x: 30, y: y),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: size)])
                y += size + 16
            }
        }
        let document = PDFDocument(data: data) ?? PDFDocument()
        if let title {
            var attributes = document.documentAttributes ?? [:]
            attributes[PDFDocumentAttribute.titleAttribute] = title
            document.documentAttributes = attributes
        }
        return document
    }

    // MARK: - Metadata wins when it is usable

    func testMetadataTitleIsPreferredOverThePageText() {
        let document = self.makeDocument(lines: [("Invoice 2026-07", 28), ("Body text", 11)],
                                         title: "Quarterly report")
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Quarterly report")
    }

    func testFileUrlInTheTitleFieldIsIgnored() {
        // Real producers write this — the app's own Document info screen shows one.
        let document = self.makeDocument(lines: [("Rental agreement", 26), ("Body text", 11)],
                                         title: "file:///private/var/mobile/Containers/Data/Application/x.pdf")
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Rental agreement")
    }

    func testPlaceholderTitleIsIgnored() {
        let document = self.makeDocument(lines: [("Rental agreement", 26)], title: "Untitled")
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Rental agreement")
    }

    func testFilenameShapedTitleIsIgnored() {
        // What the bundled test document actually carries, and it is typical: the
        // producer had nothing but the source file's name to put in the field.
        let document = self.makeDocument(lines: [("Lorem ipsum", 24), ("Body text", 11)],
                                         title: "file-sample_100kB")
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Lorem ipsum")
    }

    func testOneWordTitleWithoutFilenameMarksIsKept() {
        let document = self.makeDocument(lines: [("Body text", 11)], title: "Contratto")
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Contratto")
    }

    func testOfficeProducerPrefixAndExtensionAreStripped() {
        let document = self.makeDocument(lines: [("Body", 11)],
                                         title: "Microsoft Word - Rental agreement.docx")
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Rental agreement")
    }

    // MARK: - Falling back to the page

    func testLargestTypeOnTheFirstPageWinsOverTheFirstLine() {
        let document = self.makeDocument(lines: [("Acme Corporation", 9),
                                                 ("Via Roma 1, Milano", 9),
                                                 ("Invoice 2026-07", 30),
                                                 ("Due on receipt", 11)])
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Invoice 2026-07")
    }

    func testEqualTypeFallsBackToTheTopLine() {
        let document = self.makeDocument(lines: [("Meeting notes", 14),
                                                 ("Attendees", 14),
                                                 ("Agenda", 14)])
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Meeting notes")
    }

    func testDateAndRuleLinesAreNotProposed() {
        let document = self.makeDocument(lines: [("12/07/2026", 30),
                                                 ("--------", 28),
                                                 ("Service contract", 20)])
        XCTAssertEqual(PdfTitleUtility.suggestedName(for: document), "Service contract")
    }

    func testDocumentWithoutTextHasNoSuggestion() {
        let data = UIGraphicsPDFRenderer(bounds: Self.pageBounds).pdfData { $0.beginPage() }
        let document = PDFDocument(data: data) ?? PDFDocument()
        XCTAssertNil(PdfTitleUtility.suggestedName(for: document))
    }

    func testEmptyDocumentHasNoSuggestion() {
        XCTAssertNil(PdfTitleUtility.suggestedName(for: PDFDocument()))
    }

    // MARK: - Shaping (pure)

    func testCleanedCollapsesWhitespaceAndTrims() {
        XCTAssertEqual(PdfTitleUtility.cleaned("  Rental   agreement \n"), "Rental agreement")
    }

    func testCleanedRemovesCharactersAFilenameCannotCarry() {
        XCTAssertEqual(PdfTitleUtility.cleaned("Invoice 07/2026: final"), "Invoice 07 2026 final")
    }

    func testCleanedRejectsTheUnusable() {
        XCTAssertNil(PdfTitleUtility.cleaned(""))
        XCTAssertNil(PdfTitleUtility.cleaned("   "))
        XCTAssertNil(PdfTitleUtility.cleaned("42"))
        XCTAssertNil(PdfTitleUtility.cleaned("-----"))
        XCTAssertNil(PdfTitleUtility.cleaned("https://example.com/report"))
        XCTAssertNil(PdfTitleUtility.cleaned("/Users/someone/Documents/report"))
        XCTAssertNil(PdfTitleUtility.cleaned(String(repeating: "long body text ", count: 20)))
    }

    func testTruncationCutsOnAWordBoundary() {
        let long = "Agreement for the supply of office furniture and related services"
        let result = PdfTitleUtility.truncated(long)
        XCTAssertLessThanOrEqual(result.count, PdfTitleUtility.maxLength)
        XCTAssertTrue(long.hasPrefix(result), "the cut should be a prefix of the original")
        XCTAssertFalse(result.hasSuffix(" "))
        XCTAssertTrue(result.hasSuffix("related") || result.hasSuffix("and"),
                      "unexpected cut: \(result)")
    }

    func testShortNamesAreLeftAlone() {
        XCTAssertEqual(PdfTitleUtility.truncated("Invoice"), "Invoice")
    }
}

/// When the editor offers the name, and what happens to it.
@MainActor
final class PdfEditNameSuggestionTests: XCTestCase {

    override func tearDown() {
        Container.shared.analyticsManager.reset()
        super.tearDown()
    }

    /// A document with a readable title and the filename the app generates for one
    /// nobody has named — which is what `Pdf(data:)` leaves behind.
    private func makeUnnamedPdf() -> Pdf {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            ("Invoice 2026-07" as NSString).draw(at: CGPoint(x: 30, y: 40),
                                                 withAttributes: [.font: UIFont.systemFont(ofSize: 28)])
            ("Due on receipt" as NSString).draw(at: CGPoint(x: 30, y: 100),
                                                withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
        }
        return Pdf(data: data) ?? Pdf()
    }

    private func makeViewModel(pdf: Pdf) -> PdfEditViewModel {
        Container.shared.analyticsManager.register { SilentAnalyticsManager() }
        return PdfEditViewModel(inputParameter: .init(pdf: pdf,
                                                      startAction: nil,
                                                      shouldShowCloseWarning: .constant(false)))
    }

    func testGeneratedFilenameIsRecognised() {
        XCTAssertTrue(Pdf.isGeneratedFilename("File-07-26-2026"))
        XCTAssertFalse(Pdf.isGeneratedFilename("Rental agreement"))
        XCTAssertFalse(Pdf.isGeneratedFilename("File-07-26-2026 signed"))
    }

    func testANameIsSuggestedForADocumentNobodyHasNamed() {
        let viewModel = self.makeViewModel(pdf: self.makeUnnamedPdf())
        viewModel.refreshFilenameSuggestion()
        XCTAssertEqual(viewModel.suggestedFilename, "Invoice 2026-07")
    }

    func testNothingIsSuggestedForADocumentThatAlreadyHasAName() {
        var pdf = self.makeUnnamedPdf()
        pdf.updateFilename("Rental agreement")
        let viewModel = self.makeViewModel(pdf: pdf)
        viewModel.refreshFilenameSuggestion()
        XCTAssertNil(viewModel.suggestedFilename)
    }

    func testUsingTheSuggestionRenamesTheDocumentAndClearsTheOffer() {
        let viewModel = self.makeViewModel(pdf: self.makeUnnamedPdf())
        viewModel.refreshFilenameSuggestion()
        viewModel.useSuggestedFilename()
        XCTAssertEqual(viewModel.pdfFilename, "Invoice 2026-07")
        XCTAssertNil(viewModel.suggestedFilename)
    }

    func testDismissingItKeepsItAwayForTheRestOfTheSession() {
        let viewModel = self.makeViewModel(pdf: self.makeUnnamedPdf())
        viewModel.refreshFilenameSuggestion()
        viewModel.dismissFilenameSuggestion()
        XCTAssertNil(viewModel.suggestedFilename)
        // Adding a page or running OCR recomputes it; a dismissed offer stays gone.
        viewModel.refreshFilenameSuggestion()
        XCTAssertNil(viewModel.suggestedFilename)
    }
}

private final class SilentAnalyticsManager: AnalyticsManager {
    func track(event: AnalyticsEvent) {}
}
