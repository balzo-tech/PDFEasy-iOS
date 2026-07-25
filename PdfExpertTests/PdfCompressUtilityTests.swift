//
//  PdfCompressUtilityTests.swift
//  PdfExpertTests
//
//  Compression has to shrink the pages that are pixels, leave the pages that are
//  text alone, and never hand back a file bigger than the one it was given.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PdfCompressUtilityTests: XCTestCase {

    private static let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)

    // MARK: - Fixtures

    private func makeTextDocument(pageTexts: [String]) -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: Self.pageBounds).pdfData { context in
            for text in pageTexts {
                context.beginPage()
                (text as NSString).draw(at: CGPoint(x: 40, y: 40),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    /// A page covered by a high-resolution, hard-to-compress image — the shape of
    /// a real scan. Deterministic noise, so the test never flakes on a lucky
    /// gradient that JPEG squeezes to nothing.
    private func makeScanLikeDocument(pageCount: Int = 1) -> PDFDocument {
        let noise = self.noiseImage(size: CGSize(width: 2000, height: 2800))
        let data = UIGraphicsPDFRenderer(bounds: Self.pageBounds).pdfData { context in
            for _ in 0..<pageCount {
                context.beginPage()
                noise.draw(in: Self.pageBounds)
            }
        }
        return PDFDocument(data: data) ?? PDFDocument()
    }

    private func noiseImage(size: CGSize) -> UIImage {
        let width = Int(size.width)
        let height = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        for index in stride(from: 0, to: pixels.count, by: 4) {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let value = self.truncatedByte(seed >> 33)
            pixels[index] = value
            pixels[index + 1] = value &* 3
            pixels[index + 2] = value &* 7
            pixels[index + 3] = 255
        }
        let context = CGContext(data: &pixels,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let cgImage = context?.makeImage() else { return UIImage() }
        return UIImage(cgImage: cgImage)
    }

    private func truncatedByte(_ value: UInt64) -> UInt8 {
        UInt8(value % 256)
    }

    // MARK: - Tests

    func testScannedPageGetsSmaller() throws {
        let document = self.makeScanLikeDocument()
        let result = try XCTUnwrap(PdfCompressUtility.compress(document: document, preset: .balanced))

        XCTAssertTrue(result.isSmaller, "a high-resolution scan must shrink")
        XCTAssertEqual(result.recompressedPageCount, 1)
        XCTAssertGreaterThan(result.savedFraction, 0.2)
        XCTAssertEqual(result.document.pageCount, document.pageCount)
    }

    func testStrongerPresetProducesSmallerFile() throws {
        let document = self.makeScanLikeDocument()
        let light = try XCTUnwrap(PdfCompressUtility.compress(document: document, preset: .light))
        let balanced = try XCTUnwrap(PdfCompressUtility.compress(document: document, preset: .balanced))
        let maximum = try XCTUnwrap(PdfCompressUtility.compress(document: document, preset: .maximum))

        XCTAssertLessThan(balanced.compressedByteCount, light.compressedByteCount)
        XCTAssertLessThan(maximum.compressedByteCount, balanced.compressedByteCount)
    }

    /// The whole point of not compressing everything: a text page has to come out
    /// selectable, not flattened into an image.
    func testTextPageKeepsItsTextAndIsNotRecompressed() throws {
        let document = self.makeTextDocument(pageTexts: ["The tenant agrees to the following terms"])
        let result = try XCTUnwrap(PdfCompressUtility.compress(document: document, preset: .maximum))

        XCTAssertEqual(result.recompressedPageCount, 0)
        let text = result.document.page(at: 0)?.string ?? ""
        XCTAssertTrue(text.contains("tenant"), "text page must stay selectable, got: \(text)")
    }

    func testMixedDocumentOnlyTouchesTheScannedPages() throws {
        let text = self.makeTextDocument(pageTexts: ["Invoice number 42"])
        let scan = self.makeScanLikeDocument()
        let mixed = PDFDocument()
        if let page = text.page(at: 0)?.copy() as? PDFPage { mixed.insert(page, at: 0) }
        if let page = scan.page(at: 0)?.copy() as? PDFPage { mixed.insert(page, at: 1) }

        let result = try XCTUnwrap(PdfCompressUtility.compress(document: mixed, preset: .balanced))

        XCTAssertEqual(result.document.pageCount, 2)
        XCTAssertEqual(result.recompressedPageCount, 1)
        XCTAssertTrue((result.document.page(at: 0)?.string ?? "").contains("Invoice"))
    }

    /// Re-encoding can lose; when it does, the original page has to be kept.
    func testAlreadySmallDocumentIsNeverMadeBigger() throws {
        let document = self.makeTextDocument(pageTexts: ["Short"])
        let result = try XCTUnwrap(PdfCompressUtility.compress(document: document, preset: .maximum))

        XCTAssertLessThanOrEqual(result.compressedByteCount, result.originalByteCount)
        XCTAssertEqual(result.savedFraction, 0, accuracy: 0.0001)
    }

    /// A multi-page text document is where rebuilding from scratch used to bite:
    /// the shared font was re-emitted per page and the "compressed" file came out
    /// bigger than the original.
    func testMultiPageTextDocumentIsReportedAtItsOriginalSize() throws {
        let document = self.makeTextDocument(pageTexts: ["First page of the contract",
                                                         "Second page of the contract",
                                                         "Third page of the contract"])
        let result = try XCTUnwrap(PdfCompressUtility.compress(document: document, preset: .maximum))

        XCTAssertEqual(result.recompressedPageCount, 0)
        XCTAssertEqual(result.compressedByteCount, result.originalByteCount)
        XCTAssertFalse(result.isSmaller)
        XCTAssertEqual(result.document.pageCount, 3)
    }

    func testProgressReachesOne() throws {
        let document = self.makeScanLikeDocument(pageCount: 3)
        var reported: [Double] = []
        _ = PdfCompressUtility.compress(document: document, preset: .light) { reported.append($0) }

        XCTAssertEqual(reported.count, 3)
        XCTAssertEqual(reported.last ?? 0, 1.0, accuracy: 0.0001)
    }

    func testEmptyDocumentIsHandledWithoutCrashing() throws {
        // Whether an empty PDFDocument yields a data representation is PDFKit's
        // business; what matters is that nothing is invented and nothing crashes.
        let result = PdfCompressUtility.compress(document: PDFDocument(), preset: .balanced)
        if let result {
            XCTAssertEqual(result.document.pageCount, 0)
            XCTAssertEqual(result.recompressedPageCount, 0)
            XCTAssertFalse(result.isSmaller)
        }
    }

    func testFileSizeTextIsHumanReadable() {
        XCTAssertFalse((2_400_000).fileSizeText.isEmpty)
    }
}
