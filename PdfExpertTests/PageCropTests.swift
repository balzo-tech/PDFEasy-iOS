//
//  PageCropTests.swift
//  PdfExpertTests
//
//  Cropping a page, and the crop surviving everything that happens to the page
//  afterwards.
//
//  Two kinds of check. The arithmetic — a rectangle dragged over the page as it
//  is shown, turned into a crop box in the page's own space — is checked against
//  hand-worked numbers for each rotation and for a media box that does not start
//  at 0,0. Then, because the arithmetic agreeing with itself proves little, the
//  same crop is checked against PDFKit's own drawing: a page painted in four
//  colours is cropped to one quarter of what is *shown*, and what is drawn
//  afterwards has to be that quarter's colour and nothing else. That part is run
//  again after every operation that rebuilds or copies a page, because each of
//  them used to draw the media box and give back what had been cut away.
//

import XCTest
import PDFKit
@testable import PdfExpert

final class PageCropTests: XCTestCase {

    private let mediaBox = CGRect(x: 0, y: 0, width: 400, height: 600)
    private let offsetMediaBox = CGRect(x: 100, y: 50, width: 400, height: 600)

    // MARK: - The arithmetic

    func testUnturnedPageFlipsTheVerticalAxis() {
        // The top-left quarter of the picture is the top-left quarter of the page,
        // which in PDF space — origin bottom left — is the upper half of y.
        let crop = PDFUtility.cropBox(forNormalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
                                      mediaBox: self.mediaBox, rotation: 0)
        self.assertEqual(crop, CGRect(x: 0, y: 300, width: 200, height: 300))
    }

    func testQuarterTurnClockwise() {
        // Turned 90° clockwise the page's left edge runs along the top of the
        // picture, and its bottom edge down the picture's left side. The top-left
        // quarter of the picture is therefore the bottom-left of the page.
        let crop = PDFUtility.cropBox(forNormalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.25),
                                      mediaBox: self.mediaBox, rotation: 90)
        self.assertEqual(crop, CGRect(x: 0, y: 0, width: 100, height: 300))
    }

    func testHalfTurn() {
        let crop = PDFUtility.cropBox(forNormalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.25),
                                      mediaBox: self.mediaBox, rotation: 180)
        // Picture's top left is the page's bottom right.
        self.assertEqual(crop, CGRect(x: 200, y: 0, width: 200, height: 150))
    }

    func testThreeQuarterTurn() {
        let crop = PDFUtility.cropBox(forNormalizedRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.25),
                                      mediaBox: self.mediaBox, rotation: 270)
        // Turned 270° the page's top edge runs down the picture's left side and its
        // right edge along the top: the top-left of the picture is the top right
        // of the page.
        self.assertEqual(crop, CGRect(x: 300, y: 300, width: 100, height: 300))
    }

    func testANegativeRotationIsTheSameAsItsPositiveTwin() {
        let rect = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        self.assertEqual(PDFUtility.cropBox(forNormalizedRect: rect, mediaBox: self.mediaBox, rotation: -90),
                         PDFUtility.cropBox(forNormalizedRect: rect, mediaBox: self.mediaBox, rotation: 270))
    }

    func testAMediaBoxAwayFromTheOriginShiftsTheCrop() {
        let rect = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        for rotation in [0, 90, 180, 270] {
            let atOrigin = PDFUtility.cropBox(forNormalizedRect: rect, mediaBox: self.mediaBox, rotation: rotation)
            let shifted = PDFUtility.cropBox(forNormalizedRect: rect, mediaBox: self.offsetMediaBox, rotation: rotation)
            self.assertEqual(shifted, atOrigin.offsetBy(dx: 100, dy: 50), "rotation \(rotation)")
        }
    }

    func testTheWholePictureIsTheWholePage() {
        for rotation in [0, 90, 180, 270] {
            self.assertEqual(PDFUtility.cropBox(forNormalizedRect: PageCropGeometry.unit,
                                                mediaBox: self.offsetMediaBox, rotation: rotation),
                             self.offsetMediaBox, "rotation \(rotation)")
        }
    }

    func testARectangleHangingOffThePageIsKeptOnIt() {
        let crop = PDFUtility.cropBox(forNormalizedRect: CGRect(x: -0.5, y: 0.5, width: 1, height: 1),
                                      mediaBox: self.mediaBox, rotation: 0)
        self.assertEqual(crop, CGRect(x: 0, y: 0, width: 200, height: 300))
    }

    func testTheCropScreenOpensOnTheCurrentCrop() {
        // The way back: whatever crop a page has, the screen shows it where it is.
        let rect = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        for rotation in [0, 90, 180, 270] {
            for box in [self.mediaBox, self.offsetMediaBox] {
                let crop = PDFUtility.cropBox(forNormalizedRect: rect, mediaBox: box, rotation: rotation)
                let back = PDFUtility.normalizedRect(forCropBox: crop, mediaBox: box, rotation: rotation)
                self.assertEqual(back, rect, accuracy: 0.0001, "rotation \(rotation), media box \(box)")
            }
        }
    }

    func testAnUncroppedPageOpensOnTheWholePage() {
        XCTAssertEqual(PDFUtility.normalizedRect(forCropBox: self.offsetMediaBox,
                                                 mediaBox: self.offsetMediaBox, rotation: 90),
                       PageCropGeometry.unit)
    }

    // MARK: - The rectangle on screen

    func testDraggingACornerMovesTwoSides() {
        let rect = PageCropGeometry.rect(dragging: .topLeft, from: PageCropGeometry.unit,
                                         by: CGSize(width: 0.2, height: 0.1),
                                         minSize: CGSize(width: 0.1, height: 0.1))
        self.assertEqual(rect, CGRect(x: 0.2, y: 0.1, width: 0.8, height: 0.9))
    }

    func testDraggingASideMovesOnlyThatSide() {
        let rect = PageCropGeometry.rect(dragging: .right, from: PageCropGeometry.unit,
                                         by: CGSize(width: -0.3, height: 0.4),
                                         minSize: CGSize(width: 0.1, height: 0.1))
        self.assertEqual(rect, CGRect(x: 0, y: 0, width: 0.7, height: 1))
    }

    func testASideStopsShortOfTheOppositeOne() {
        let rect = PageCropGeometry.rect(dragging: .left, from: PageCropGeometry.unit,
                                         by: CGSize(width: 5, height: 0),
                                         minSize: CGSize(width: 0.1, height: 0.1))
        XCTAssertEqual(rect.width, 0.1, accuracy: 0.0001)
        XCTAssertEqual(rect.maxX, 1, accuracy: 0.0001)
    }

    func testASideStopsAtTheEdgeOfThePage() {
        let start = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        let rect = PageCropGeometry.rect(dragging: .bottomRight, from: start,
                                         by: CGSize(width: 3, height: 3),
                                         minSize: CGSize(width: 0.1, height: 0.1))
        self.assertEqual(rect, CGRect(x: 0.2, y: 0.2, width: 0.8, height: 0.8))
    }

    func testDraggingFromInsideKeepsTheSizeAndStaysOnThePage() {
        let start = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        let rect = PageCropGeometry.rect(dragging: .body, from: start,
                                         by: CGSize(width: 0.9, height: -0.9),
                                         minSize: CGSize(width: 0.1, height: 0.1))
        self.assertEqual(rect, CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
    }

    // MARK: - What the page looks like afterwards

    /// The check that matters: crop each rotation of a four-colour page to one
    /// quarter of the page *as shown*, and the page then draws as that quarter —
    /// the colour PDFKit itself showed there before the crop, everywhere.
    func testTheAreaKeptIsTheAreaChosenInEveryRotation() throws {
        for origin in [CGPoint.zero, CGPoint(x: 100, y: 50)] {
            for rotation in [0, 90, 180, 270] {
                for quarter in Self.quarters {
                    let page = try self.makeQuarteredPage(origin: origin, rotation: rotation)
                    let expected = try self.colour(of: PDFUtility.generatePageImage(page),
                                                   at: CGPoint(x: quarter.midX, y: quarter.midY))

                    PDFUtility.cropPage(page, toNormalizedRect: quarter)

                    try self.assertDrawsOnly(expected, PDFUtility.generatePageImage(page),
                                             "origin \(origin), rotation \(rotation), quarter \(quarter)")
                }
            }
        }
    }

    func testCroppingToTheWholePageUndoesTheCrop() throws {
        let page = try self.makeQuarteredPage(origin: CGPoint(x: 100, y: 50), rotation: 90)
        PDFUtility.cropPage(page, toNormalizedRect: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
        XCTAssertNotEqual(page.bounds(for: .cropBox), page.bounds(for: .mediaBox))

        PDFUtility.cropPage(page, toNormalizedRect: PageCropGeometry.unit)

        XCTAssertEqual(page.bounds(for: .cropBox), page.bounds(for: .mediaBox))
    }

    // MARK: - Surviving what happens next

    /// Saved and opened again — and the strip's thumbnail, which drew the trim
    /// box: PDFKit writes the trim box out at the full media box when it saves,
    /// so a cropped page came back whole in the strip.
    func testACroppedPageIsStillCroppedOnceSavedAndOpenedAgain() throws {
        let (document, expected) = try self.makeCroppedDocument(rotation: 90)

        let data = try XCTUnwrap(document.dataRepresentation())
        let reopened = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(reopened.page(at: 0))

        XCTAssertLessThan(page.bounds(for: .cropBox).width * page.bounds(for: .cropBox).height,
                          page.bounds(for: .mediaBox).width * page.bounds(for: .mediaBox).height * 0.5,
                          "the crop box did not survive the save")
        try self.assertDrawsOnly(expected, PDFUtility.generatePageImage(page), "page image after a save")
        let thumbnail = try XCTUnwrap(PDFUtility.generatePdfThumbnail(pdfDocument: reopened,
                                                                       size: CGSize(width: 60, height: 60),
                                                                       forPageIndex: 0))
        try self.assertDrawsOnly(expected, thumbnail, "thumbnail after a save")
    }

    func testTheThumbnailIsCropped() throws {
        let (document, expected) = try self.makeCroppedDocument(rotation: 0)
        let thumbnail = try XCTUnwrap(PDFUtility.generatePdfThumbnail(pdfDocument: document,
                                                                       size: CGSize(width: 60, height: 60),
                                                                       forPageIndex: 0))
        try self.assertDrawsOnly(expected, thumbnail, "thumbnail")
    }

    /// The editor draws its pages, and duplicates them, from a detached copy.
    func testADetachedPageKeepsTheCrop() throws {
        let (document, expected) = try self.makeCroppedDocument(rotation: 270)
        let detached = try XCTUnwrap(PDFUtility.detachedPage(from: try XCTUnwrap(document.page(at: 0))))
        try self.assertDrawsOnly(expected, PDFUtility.generatePageImage(detached), "detached page")
    }

    func testMergingKeepsTheCrop() throws {
        let (document, expected) = try self.makeCroppedDocument(rotation: 90)
        let merged = PDFDocument()
        PDFUtility.appendPdfDocument(document, toPdfDocument: merged)
        let reopened = try XCTUnwrap(merged.dataRepresentation().flatMap { PDFDocument(data: $0) })
        try self.assertDrawsOnly(expected, PDFUtility.generatePageImage(try XCTUnwrap(reopened.page(at: 0))),
                                 "merged page")
    }

    func testExtractingKeepsTheCrop() throws {
        let (document, expected) = try self.makeCroppedDocument(rotation: 180)
        let extracted = PDFUtility.extractPages(fromDocument: document, pageRanges: [0...0, 0...0])
        for index in 0..<2 {
            try self.assertDrawsOnly(expected,
                                     PDFUtility.generatePageImage(try XCTUnwrap(extracted.page(at: index))),
                                     "extracted page \(index)")
        }
    }

    /// Flatten, invert, page numbers and the watermark all rebuild the page
    /// through `redrawPages`, which drew the media box.
    func testRedrawingThePagesKeepsTheCrop() throws {
        let (document, expected) = try self.makeCroppedDocument(rotation: 90)
        let flattened = try XCTUnwrap(PdfCleanupUtility.flatten(document))
        try self.assertDrawsOnly(expected, PDFUtility.generatePageImage(try XCTUnwrap(flattened.page(at: 0))),
                                 "flattened page")
    }

    func testProtectingThePageKeepsTheCrop() throws {
        let (document, expected) = try self.makeCroppedDocument(rotation: 90)
        let data = try XCTUnwrap(PdfPermissionsUtility.apply(to: document,
                                                             ownerPassword: "owner",
                                                             permissions: PdfPermissions(allowsPrinting: false,
                                                                                         allowsCopying: false)))
        let protected = try XCTUnwrap(PDFDocument(data: data))
        try self.assertDrawsOnly(expected, PDFUtility.generatePageImage(try XCTUnwrap(protected.page(at: 0))),
                                 "protected page")
    }

    func testRemovingThePasswordKeepsTheCrop() throws {
        let (document, expected) = try self.makeCroppedDocument(rotation: 90)
        let locked = try XCTUnwrap(document.dataRepresentation(options: [
            PDFDocumentWriteOption.userPasswordOption: "secret",
            PDFDocumentWriteOption.ownerPasswordOption: "secret"
        ]))
        let unlocked = try XCTUnwrap(PDFUtility.removePassword(data: locked, existingPDFPassword: "secret"))
        let page = try XCTUnwrap(PDFDocument(data: unlocked)?.page(at: 0))
        try self.assertDrawsOnly(expected, PDFUtility.generatePageImage(page), "unlocked page")
    }

    // MARK: - Fixtures

    /// The four quarters of the page as shown, in the unit, top-left coordinates
    /// the crop screen works in.
    private static let quarters: [CGRect] = [
        CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
        CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
        CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
        CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
    ]

    /// A page painted in four colours, one per quarter of its media box, written
    /// out by hand so the media box can start somewhere other than 0,0.
    private func makeQuarteredPage(origin: CGPoint, rotation: Int) throws -> PDFPage {
        try self.makeQuarteredDocument(origin: origin, rotation: rotation).page
    }

    /// The same page with its document, which a test that goes on to use the
    /// document has to hold: a page only keeps a weak reference to it.
    private func makeQuarteredDocument(origin: CGPoint, rotation: Int) throws -> (document: PDFDocument, page: PDFPage) {
        let (x, y) = (Int(origin.x), Int(origin.y))
        let content = [
            "1 0 0 rg \(x) \(y) 200 300 re f",
            "0 1 0 rg \(x + 200) \(y) 200 300 re f",
            "0 0 1 rg \(x) \(y + 300) 200 300 re f",
            "1 1 0 rg \(x + 200) \(y + 300) 200 300 re f"
        ].joined(separator: "\n")
        let pdf = """
        %PDF-1.4
        1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
        2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
        3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [\(x) \(y) \(x + 400) \(y + 600)] /Contents 4 0 R >> endobj
        4 0 obj << /Length \(content.utf8.count) >> stream
        \(content)
        endstream endobj
        trailer << /Root 1 0 R >>
        %%EOF
        """
        let document = try XCTUnwrap(PDFDocument(data: Data(pdf.utf8)))
        let page = try XCTUnwrap(document.page(at: 0))
        page.rotation = rotation
        return (document, page)
    }

    /// A one-page document cropped to the top-right quarter of what is shown,
    /// and the colour that quarter is.
    private func makeCroppedDocument(rotation: Int) throws -> (PDFDocument, Colour) {
        let (document, page) = try self.makeQuarteredDocument(origin: CGPoint(x: 100, y: 50), rotation: rotation)
        let quarter = CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        let expected = try self.colour(of: PDFUtility.generatePageImage(page),
                                       at: CGPoint(x: quarter.midX, y: quarter.midY))
        PDFUtility.cropPage(page, toNormalizedRect: quarter)
        return (document, expected)
    }

    private struct Colour: Equatable, CustomStringConvertible {
        let r: Int, g: Int, b: Int
        var description: String { "(\(self.r), \(self.g), \(self.b))" }

        func isClose(to other: Colour) -> Bool {
            abs(self.r - other.r) < 40 && abs(self.g - other.g) < 40 && abs(self.b - other.b) < 40
        }
    }

    /// The colour at a point given in unit, top-left coordinates.
    private func colour(of image: UIImage, at point: CGPoint) throws -> Colour {
        let cgImage = try XCTUnwrap(image.cgImage)
        let (width, height) = (cgImage.width, cgImage.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height,
                                              bitsPerComponent: 8, bytesPerRow: width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Bitmap rows start at the top, so a top-left y reads straight across.
        let x = min(max(Int(point.x * CGFloat(width)), 0), width - 1)
        let y = min(max(Int(point.y * CGFloat(height)), 0), height - 1)
        let offset = (y * width + x) * 4
        return Colour(r: Int(pixels[offset]), g: Int(pixels[offset + 1]), b: Int(pixels[offset + 2]))
    }

    /// Samples the image well inside each corner and in the middle: a crop that
    /// kept the wrong area, or kept the whole page, shows a second colour in at
    /// least one of them. Checked on all three channels, since white has a full
    /// red and a full green.
    private func assertDrawsOnly(_ expected: Colour, _ image: UIImage, _ message: String,
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        for point in [CGPoint(x: 0.12, y: 0.12), CGPoint(x: 0.88, y: 0.12), CGPoint(x: 0.5, y: 0.5),
                      CGPoint(x: 0.12, y: 0.88), CGPoint(x: 0.88, y: 0.88)] {
            let found = try self.colour(of: image, at: point)
            XCTAssertTrue(found.isClose(to: expected),
                          "\(message): \(found) at \(point), expected \(expected)", file: file, line: line)
        }
    }

    private func assertEqual(_ a: CGRect, _ b: CGRect, accuracy: CGFloat = 0.5, _ message: String = "",
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.minX, b.minX, accuracy: accuracy, "minX \(message)", file: file, line: line)
        XCTAssertEqual(a.minY, b.minY, accuracy: accuracy, "minY \(message)", file: file, line: line)
        XCTAssertEqual(a.width, b.width, accuracy: accuracy, "width \(message)", file: file, line: line)
        XCTAssertEqual(a.height, b.height, accuracy: accuracy, "height \(message)", file: file, line: line)
    }
}
