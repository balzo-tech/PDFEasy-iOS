//
//  ScanImageProcessorTests.swift
//  PdfExpertTests
//
//  What comes out of the scanner pipeline, checked on the pixels rather than on
//  the intent: that the crop actually crops, that a quarter turn actually
//  swaps the sides, that "greyscale" leaves no colour behind and "black & white"
//  leaves nothing in between.
//
//  Every fixture is drawn here rather than bundled, so the numbers below are
//  derived from something the test itself can point at.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class ScanImageProcessorTests: XCTestCase {

    // MARK: - Fixtures

    /// A dark frame with a lighter, coloured "page" over the middle half — the
    /// shape of a photographed document.
    private func makePhoto(size: CGSize = CGSize(width: 400, height: 800)) -> UIImage {
        UIGraphicsImageRenderer(size: size, format: Self.format).image { context in
            UIColor(white: 0.15, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.9, green: 0.75, blue: 0.4, alpha: 1).setFill()
            context.fill(CGRect(x: size.width * 0.25, y: size.height * 0.25,
                                width: size.width * 0.5, height: size.height * 0.5))
        }
    }

    private static var format: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat.default()
        // Scale 1 so points and pixels are the same number in the assertions.
        format.scale = 1
        return format
    }

    private let pageQuad = ScanQuad(topLeft: CGPoint(x: 0.25, y: 0.25),
                                    topRight: CGPoint(x: 0.75, y: 0.25),
                                    bottomRight: CGPoint(x: 0.75, y: 0.75),
                                    bottomLeft: CGPoint(x: 0.25, y: 0.75))

    /// Average colour of the middle of an image, as 0…255 components.
    private func centerPixel(of image: UIImage) throws -> (r: Int, g: Int, b: Int) {
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel,
                                              width: 1,
                                              height: 1,
                                              bitsPerComponent: 8,
                                              bytesPerRow: 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage,
                     in: CGRect(x: -CGFloat(cgImage.width) / 2 + 0.5,
                                y: -CGFloat(cgImage.height) / 2 + 0.5,
                                width: CGFloat(cgImage.width),
                                height: CGFloat(cgImage.height)))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }

    // MARK: - Cropping

    func testRenderingWithoutACropKeepsTheWholeFrame() throws {
        let photo = self.makePhoto()
        let page = ScannedPage(original: photo, quad: nil, filter: .original)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        XCTAssertEqual(rendered.size.width, photo.size.width, accuracy: 1)
        XCTAssertEqual(rendered.size.height, photo.size.height, accuracy: 1)
    }

    func testACropCutsTheFrameDownToThePage() throws {
        let photo = self.makePhoto()
        let page = ScannedPage(original: photo, quad: self.pageQuad, filter: .original)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        XCTAssertEqual(rendered.size.width, photo.size.width / 2, accuracy: 2)
        XCTAssertEqual(rendered.size.height, photo.size.height / 2, accuracy: 2)
    }

    /// Reported from the phone: "I moved the corners well in and it still gives
    /// me the whole image". A crop under a sixth of the frame was being dropped
    /// on the way to Core Image, because rendering was asking the detector's
    /// question — is this likely to be a page? — about a shape the user had
    /// already decided on.
    func testACropSmallerThanTheDetectorWouldProposeIsStillApplied() throws {
        let photo = self.makePhoto()
        let stamp = ScanQuad(topLeft: CGPoint(x: 0.40, y: 0.40),
                             topRight: CGPoint(x: 0.52, y: 0.40),
                             bottomRight: CGPoint(x: 0.52, y: 0.52),
                             bottomLeft: CGPoint(x: 0.40, y: 0.52))
        let page = ScannedPage(original: photo, quad: stamp, filter: .original)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        XCTAssertEqual(rendered.size.width, photo.size.width * 0.12, accuracy: 2)
        XCTAssertLessThan(rendered.size.width, photo.size.width / 4,
                          "the crop was ignored and the whole frame came back")
    }

    func testAFullFrameQuadIsTreatedAsNoCrop() throws {
        let photo = self.makePhoto()
        let page = ScannedPage(original: photo, quad: .full, filter: .original)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        XCTAssertEqual(rendered.size.width, photo.size.width, accuracy: 1)
    }

    func testTheCroppedResultIsThePageAndNotTheBackground() throws {
        let page = ScannedPage(original: self.makePhoto(), quad: self.pageQuad, filter: .original)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        let pixel = try self.centerPixel(of: rendered)
        // The page is warm and light; the surround is near-black.
        XCTAssertGreaterThan(pixel.r, 150)
        XCTAssertGreaterThan(pixel.r, pixel.b)
    }

    // MARK: - Rotation

    func testAQuarterTurnSwapsTheSides() throws {
        let photo = self.makePhoto()
        let page = ScannedPage(original: photo, quad: nil, filter: .original, rotation: .quarter)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        XCTAssertEqual(rendered.size.width, photo.size.height, accuracy: 1)
        XCTAssertEqual(rendered.size.height, photo.size.width, accuracy: 1)
    }

    func testAHalfTurnKeepsTheSides() throws {
        let photo = self.makePhoto()
        let page = ScannedPage(original: photo, quad: nil, filter: .original, rotation: .half)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        XCTAssertEqual(rendered.size.width, photo.size.width, accuracy: 1)
        XCTAssertEqual(rendered.size.height, photo.size.height, accuracy: 1)
    }

    // MARK: - Filters

    func testGreyscaleLeavesNoColourBehind() throws {
        let page = ScannedPage(original: self.makePhoto(), quad: self.pageQuad, filter: .grayscale)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        let pixel = try self.centerPixel(of: rendered)
        XCTAssertEqual(pixel.r, pixel.g, accuracy: 2)
        XCTAssertEqual(pixel.g, pixel.b, accuracy: 2)
    }

    func testBlackAndWhiteLeavesNothingInBetween() throws {
        let page = ScannedPage(original: self.makePhoto(), quad: self.pageQuad, filter: .blackAndWhite)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        let pixel = try self.centerPixel(of: rendered)
        XCTAssertTrue(pixel.r < 12 || pixel.r > 243, "Otsu's threshold should produce one extreme or the other, got \(pixel.r)")
    }

    func testTheDocumentFilterKeepsAPageLight() throws {
        // The whole point of the default filter is a page that reads like paper:
        // if the enhancer comes back darker than the capture, it is working
        // against the scan rather than for it.
        let page = ScannedPage(original: self.makePhoto(), quad: self.pageQuad, filter: .document)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page))
        let pixel = try self.centerPixel(of: rendered)
        XCTAssertGreaterThan(pixel.r, 150, "the document filter darkened the page to \(pixel)")
    }

    func testTheOriginalFilterIsAPassThrough() throws {
        let photo = self.makePhoto()
        let untouched = ScannedPage(original: photo, quad: nil, filter: .original)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(untouched))
        let before = try self.centerPixel(of: photo)
        let after = try self.centerPixel(of: rendered)
        XCTAssertEqual(before.r, after.r, accuracy: 3)
        XCTAssertEqual(before.b, after.b, accuracy: 3)
    }

    // MARK: - Downscaling

    func testTheLongestSideIsCappedWhenAskedFor() throws {
        let page = ScannedPage(original: self.makePhoto(size: CGSize(width: 2000, height: 4000)),
                               quad: nil,
                               filter: .original)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page, maxDimension: 500))
        XCTAssertEqual(max(rendered.size.width, rendered.size.height), 500, accuracy: 1)
        XCTAssertEqual(rendered.size.width / rendered.size.height, 0.5, accuracy: 0.01)
    }

    func testASmallImageIsNotBlownUp() throws {
        let photo = self.makePhoto(size: CGSize(width: 100, height: 200))
        let page = ScannedPage(original: photo, quad: nil, filter: .original)
        let rendered = try XCTUnwrap(ScanImageProcessor.render(page, maxDimension: 4000))
        XCTAssertEqual(rendered.size.height, 200, accuracy: 1)
    }

    // MARK: - Render keys

    func testEditingAPageChangesItsRenderKey() {
        let page = ScannedPage(original: self.makePhoto(), quad: nil, filter: .original)
        var edited = page
        edited.filter = .document
        XCTAssertNotEqual(page.renderKey, edited.renderKey)

        var turned = page
        turned.rotation = .quarter
        XCTAssertNotEqual(page.renderKey, turned.renderKey)

        var cropped = page
        cropped.quad = self.pageQuad
        XCTAssertNotEqual(page.renderKey, cropped.renderKey)
    }

    func testAnUnchangedPageKeepsItsRenderKey() {
        let page = ScannedPage(original: self.makePhoto(), quad: self.pageQuad, filter: .document)
        XCTAssertEqual(page.renderKey, page.renderKey)
    }

    // MARK: - PDF assembly

    func testPageBoundsKeepTheImageProportions() {
        let bounds = PdfScanUtility.pageBounds(forImageSize: CGSize(width: 1000, height: 2000))
        XCTAssertEqual(bounds.height, max(K.Misc.PdfPageSize.width, K.Misc.PdfPageSize.height), accuracy: 1)
        XCTAssertEqual(bounds.width / bounds.height, 0.5, accuracy: 0.01)
    }

    func testPageBoundsFallBackToA4ForAnEmptyImage() {
        let bounds = PdfScanUtility.pageBounds(forImageSize: .zero)
        XCTAssertEqual(bounds.size, K.Misc.PdfPageSize)
    }

    func testALandscapePageStaysLandscape() {
        let bounds = PdfScanUtility.pageBounds(forImageSize: CGSize(width: 3000, height: 1500))
        XCTAssertGreaterThan(bounds.width, bounds.height)
    }

    func testMakeDocumentProducesOnePdfPagePerScan() {
        let pages = (0..<3).map { _ in
            ScannedPage(original: self.makePhoto(), quad: self.pageQuad, filter: .document)
        }
        let document = PdfScanUtility.makeDocument(from: pages)
        XCTAssertEqual(document.pageCount, 3)
    }

    func testMakeDocumentReportsProgressForEveryPage() {
        let pages = (0..<3).map { _ in ScannedPage(original: self.makePhoto(), filter: .original) }
        var reported: [Int] = []
        _ = PdfScanUtility.makeDocument(from: pages) { reported.append($0) }
        XCTAssertEqual(reported, [1, 2, 3])
    }

    func testMakeDocumentOnNothingProducesAnEmptyDocument() {
        XCTAssertEqual(PdfScanUtility.makeDocument(from: []).pageCount, 0)
    }

    func testTheDefaultNameIsDatedAndTimed() {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 26
        components.hour = 14
        components.minute = 49
        components.second = 26
        let date = Calendar.current.date(from: components) ?? Date()
        XCTAssertEqual(PdfScanUtility.defaultFilename(date: date), "Scan 2026-07-26 14.49.26")
    }
}
