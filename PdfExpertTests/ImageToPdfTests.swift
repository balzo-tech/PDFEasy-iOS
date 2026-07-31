//
//  ImageToPdfTests.swift
//  PdfExpertTests
//
//  Reported from the phone: "Image to PDF, picking a photo from the library,
//  shows everything white — the image is not there."
//
//  A photo from the library carries an orientation flag; one taken in portrait
//  is usually `.right`, the pixels landscape with a note saying which way is up.
//  The conversion runs the image through `fixedOrientation()` and `scaledImage()`
//  before drawing it into a page, and both build a `CGContext` out of the source
//  image's own bitmap layout — bits per component, byte order, bytes per row.
//  So the question these tests ask is the reported one: for each orientation, and
//  for a photo whose layout is not the convenient one, does anything land on the
//  page at all?
//

import XCTest
import PDFKit
@testable import PdfExpert

final class ImageToPdfTests: XCTestCase {

    // MARK: - Fixtures

    /// A picture that is unmistakably not blank: solid red, big enough to be
    /// scaled down on its way into the page.
    private func makePhoto(size: CGSize = CGSize(width: 2400, height: 1800),
                           orientation: UIImage.Orientation = .up,
                           colour: UIColor = .red) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let flat = renderer.image { context in
            colour.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard orientation != .up else { return flat }
        let cgImage = flat.cgImage!
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
    }

    /// Reads the middle pixel of an image as drawn.
    private func centrePixel(of image: UIImage) throws -> (r: Int, g: Int, b: Int) {
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1,
                                             bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: -CGFloat(cgImage.width) / 2 + 0.5,
                                         y: -CGFloat(cgImage.height) / 2 + 0.5,
                                         width: CGFloat(cgImage.width),
                                         height: CGFloat(cgImage.height)))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }

    /// Reads the middle of the first page of `document` as it would be drawn.
    private func centrePixelOfFirstPage(of document: PDFDocument) throws -> (r: Int, g: Int, b: Int) {
        let page = try XCTUnwrap(document.page(at: 0), "the document has no page")
        let bounds = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: bounds.size))
            context.cgContext.translateBy(x: 0, y: bounds.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
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

    // MARK: - Every orientation a photo can arrive in

    func testAPhotoBecomesAPageThatIsNotBlank() throws {
        for orientation in [UIImage.Orientation.up, .right, .left, .down,
                            .upMirrored, .rightMirrored, .leftMirrored, .downMirrored] {
            let photo = self.makePhoto(orientation: orientation)
            let document = PDFUtility.convertUiImageToPdf(uiImage: photo)

            XCTAssertEqual(document.pageCount, 1,
                           "orientation \(orientation.rawValue) produced no page")
            let pixel = try self.centrePixelOfFirstPage(of: document)
            XCTAssertGreaterThan(pixel.r, 150,
                                 "orientation \(orientation.rawValue): the middle of the page is not the photo")
            XCTAssertLessThan(pixel.g, 100,
                              "orientation \(orientation.rawValue): the page is blank or washed out — r\(pixel.r) g\(pixel.g) b\(pixel.b)")
        }
    }

    /// The image the library actually hands over is not a freshly rendered
    /// bitmap: it has been through a codec. Round-tripping through JPEG data is
    /// the closest a unit test gets to that, and it changes exactly the things
    /// the two helpers copy — byte order, alpha, bytes per row.
    func testAPhotoThatCameThroughACodecIsNotBlankEither() throws {
        for orientation in [UIImage.Orientation.up, .right] {
            let data = try XCTUnwrap(self.makePhoto(orientation: orientation).jpegData(compressionQuality: 0.9))
            let decoded = try XCTUnwrap(UIImage(data: data))
            let document = PDFUtility.convertUiImageToPdf(uiImage: decoded)

            XCTAssertEqual(document.pageCount, 1)
            let pixel = try self.centrePixelOfFirstPage(of: document)
            XCTAssertGreaterThan(pixel.r, 150,
                                 "a decoded photo (\(orientation.rawValue)) did not reach the page — r\(pixel.r) g\(pixel.g) b\(pixel.b)")
        }
    }

    /// The editor does not draw the page it was given: it draws a *copy*, on a
    /// background queue, so that rotating or deleting a page mid-render cannot
    /// pull the ground out from under it (`PdfEditViewModel.drawPageImage`).
    ///
    /// That is the difference between this and the tests above, and it is the
    /// reported bug: a page built inside a throwaway `PDFDocument` and then
    /// inserted into another one keeps pointing at the document that made it, and
    /// once that has gone the copy has no picture left to draw. A scan does not
    /// hit this because it reaches the editor through the archive, which
    /// serialises the document on the way in.
    func testTheDetachedPageTheEditorDrawsIsNotBlank() throws {
        let document = PDFUtility.convertUiImageToPdf(uiImage: self.makePhoto(orientation: .right))
        let page = try XCTUnwrap(document.page(at: 0))

        // What `page.copy()` gives back, for the record: a page that draws white.
        // This is the bug, kept as a measurement so nobody reintroduces the copy.
        let copy = try XCTUnwrap(page.copy() as? PDFPage)
        let fromCopy = try self.centrePixel(of: PDFUtility.generatePageImage(copy))
        XCTAssertEqual(fromCopy.r, 255)
        XCTAssertEqual(fromCopy.g, 255, "a copied page used to draw the picture; if it does now, simplify detachedPage")

        // And what the editor uses instead.
        let detached = try XCTUnwrap(PDFUtility.detachedPage(from: page))
        let pixel = try self.centrePixel(of: PDFUtility.generatePageImage(detached))
        XCTAssertGreaterThan(pixel.r, 150)
        XCTAssertLessThan(pixel.g, 100,
                          "the page the editor draws is blank — r\(pixel.r) g\(pixel.g) b\(pixel.b)")
    }

    /// The editor's strip and its first frame come from
    /// `generatePdfThumbnail(size:)`, which draws the page for **`.trimBox`** —
    /// while the full-size image next to it uses `.mediaBox`. A PDF written by
    /// `UIGraphicsPDFRenderer` declares no TrimBox at all, and a scan only
    /// escapes this because it reaches the editor through the archive, which
    /// serialises the document and gives PDFKit a chance to write the boxes out.
    ///
    /// So: does a freshly converted photo have a thumbnail with a picture in it?
    func testTheThumbnailOfAFreshlyConvertedPhotoIsNotBlank() throws {
        let document = PDFUtility.convertUiImageToPdf(uiImage: self.makePhoto())
        let page = try XCTUnwrap(document.page(at: 0))

        // What the boxes actually say, reported rather than assumed.
        let media = page.bounds(for: .mediaBox)
        let trim = page.bounds(for: .trimBox)
        print("BOXES media=\(media) trim=\(trim)")

        let thumbnail = try XCTUnwrap(PDFUtility.generatePdfThumbnail(pdfDocument: document,
                                                                     size: K.Misc.ThumbnailEditSize),
                                      "no thumbnail at all")
        let pixel = try self.centrePixel(of: thumbnail)
        XCTAssertGreaterThan(pixel.r, 150,
                             "the editor's thumbnail is blank — r\(pixel.r) g\(pixel.g) b\(pixel.b)")
        XCTAssertLessThan(pixel.g, 100, "the thumbnail is washed out")
    }

    /// The same document after a round trip through its own bytes, which is what
    /// saving to the archive does. If this one passes while the test above fails,
    /// the difference between a photo and a scan is exactly that trip.
    func testTheThumbnailIsFineOnceTheDocumentHasBeenThroughItsOwnBytes() throws {
        let document = PDFUtility.convertUiImageToPdf(uiImage: self.makePhoto())
        let data = try XCTUnwrap(document.dataRepresentation())
        let reloaded = try XCTUnwrap(PDFDocument(data: data))

        let thumbnail = try XCTUnwrap(PDFUtility.generatePdfThumbnail(pdfDocument: reloaded,
                                                                     size: K.Misc.ThumbnailEditSize))
        let pixel = try self.centrePixel(of: thumbnail)
        XCTAssertGreaterThan(pixel.r, 150,
                             "even a serialised document draws blank — r\(pixel.r) g\(pixel.g) b\(pixel.b)")
    }

    /// The whole chain the report describes, in one go: a photo converted, handed
    /// to the editor exactly as `HomeViewModel` hands it over, and then asked for
    /// the picture the pager puts on screen — `pageImage(at:)` if it is drawn,
    /// the page's thumbnail if not. That expression is the screen. If it is white
    /// here, it is white on the phone.
    ///
    /// It is not a photo test any more: the report says the page is white whether
    /// the image came from the library, the camera or Files, and all three arrive
    /// here.
    func testTheEditorShowsThePhotoItWasOpenedWith() throws {
        let pdf = Pdf(pdfDocument: PDFUtility.convertUiImageToPdf(uiImage: self.makePhoto()),
                      filename: "photo",
                      source: .unknown)
        let viewModel = PdfEditViewModel(inputParameter: .init(pdf: pdf,
                                                              startAction: nil,
                                                              shouldShowCloseWarning: .constant(false)))

        let deadline = Date().addingTimeInterval(20)
        while viewModel.isPreparingPages, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertFalse(viewModel.isPreparingPages, "the pages never finished drawing")
        XCTAssertEqual(viewModel.pages.count, 1, "the editor did not list the page")

        // And wait for the full-size render too, which is the one that was blank.
        // Without this the test settles for the thumbnail and proves nothing.
        while viewModel.pageImage(at: 0) == nil, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertNotNil(viewModel.pageImage(at: 0), "the full-size page was never drawn")

        // Which of the two is white matters: they are drawn by different code on
        // different queues, so say so rather than reporting "the editor".
        let drawn = viewModel.pageImage(at: 0)
        let thumbnail = viewModel.pageThumbnail(at: 0)
        print("EDITOR pageImage=\(drawn.map { "\($0.size)" } ?? "nil") thumbnail=\(thumbnail.map { "\($0.size)" } ?? "nil")")
        if let drawn { print("EDITOR pageImage pixel: \(try self.centrePixel(of: drawn))") }
        if let thumbnail { print("EDITOR thumbnail pixel: \(try self.centrePixel(of: thumbnail))") }
        print("EDITOR document pages=\(viewModel.pdf.pdfDocument.pageCount) bounds=\(viewModel.pdf.pdfDocument.page(at: 0)?.bounds(for: .mediaBox) ?? .zero)")

        // Exactly what PdfEditView draws.
        let shown = try XCTUnwrap(drawn ?? thumbnail,
                                  "the editor has neither a page image nor a thumbnail to show")
        let pixel = try self.centrePixel(of: shown)
        XCTAssertGreaterThan(pixel.r, 150,
                             "the editor is showing a white page — r\(pixel.r) g\(pixel.g) b\(pixel.b)")
        XCTAssertLessThan(pixel.g, 100, "the editor's page is washed out")
    }

    /// Where the white comes from: `generatePdfThumbnail(size:)` multiplies the
    /// requested size by `UIScreen.main.nativeScale`, and `refreshPages()` calls
    /// it from a background queue. Read off the main thread that returns 0, the
    /// target size collapses, and `thumbnail(of: .zero)` hands back a blank image.
    /// Called on the main thread the same code draws the picture — which is why
    /// every test above passed while the editor showed white.
    func testTheThumbnailIsBlankWhenItIsDrawnOffTheMainThread() throws {
        let document = PDFUtility.convertUiImageToPdf(uiImage: self.makePhoto())

        let onMain = try XCTUnwrap(PDFUtility.generatePdfThumbnail(pdfDocument: document,
                                                                  size: K.Misc.ThumbnailEditSize))
        XCTAssertGreaterThan(try self.centrePixel(of: onMain).r, 150)
        XCTAssertLessThan(try self.centrePixel(of: onMain).g, 100, "even on the main thread it is blank")

        let expectation = self.expectation(description: "drawn off the main thread")
        var offMain: UIImage?
        var scaleSeenOffMain: CGFloat = -1
        DispatchQueue.global(qos: .userInitiated).async {
            scaleSeenOffMain = UIScreen.main.nativeScale
            offMain = PDFUtility.generatePdfThumbnail(pdfDocument: document,
                                                      size: K.Misc.ThumbnailEditSize)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 10)

        print("SCALE off main thread: \(scaleSeenOffMain)")
        let image = try XCTUnwrap(offMain, "no thumbnail came back at all")
        let pixel = try self.centrePixel(of: image)
        XCTAssertLessThan(pixel.g, 100,
                          "the thumbnail drawn off the main thread is blank — r\(pixel.r) g\(pixel.g) b\(pixel.b), scale \(scaleSeenOffMain)")
    }

    /// Four combinations, one variable at a time: the page or a copy of it, on the
    /// main thread or off it, always through the code the editor uses. Whichever
    /// line comes back white is the bug.
    func testWhichCombinationDrawsWhite() throws {
        let document = PDFUtility.convertUiImageToPdf(uiImage: self.makePhoto())
        let page = try XCTUnwrap(document.page(at: 0))
        let copy = try XCTUnwrap(page.copy() as? PDFPage)
        print("MATRIX copy.document is nil: \(copy.document == nil)")

        func report(_ label: String, _ image: UIImage) throws {
            let pixel = try self.centrePixel(of: image)
            print("MATRIX \(label): r\(pixel.r) g\(pixel.g) b\(pixel.b) size \(image.size)")
        }

        try report("page/main    ", PDFUtility.generatePageImage(page))
        try report("copy/main    ", PDFUtility.generatePageImage(copy))

        for (label, subject) in [("page/background", page), ("copy/background", copy)] {
            let expectation = self.expectation(description: label)
            var result: UIImage?
            DispatchQueue.global(qos: .userInitiated).async {
                result = PDFUtility.generatePageImage(subject)
                expectation.fulfill()
            }
            self.wait(for: [expectation], timeout: 10)
            try report(label, try XCTUnwrap(result))
        }
    }

    /// Reported from the phone: "Image to PDF does not let me pick more than one
    /// photo". The picker was asking for a single `PhotosPickerItem`; what it hands
    /// over now is a list, and each picture has to become its own page **in the
    /// order they were chosen** — a set of photos of a contract is not a document
    /// if page three comes first.
    func testEveryPhotoBecomesItsOwnPageInTheOrderTheyWerePicked() throws {
        let colours: [UIColor] = [.red, .green, .blue]
        let document = PDFDocument()
        for colour in colours {
            PDFUtility.appendImageToPdfDocument(pdfDocument: document,
                                                uiImage: self.makePhoto(colour: colour))
        }

        XCTAssertEqual(document.pageCount, colours.count,
                       "three photos did not make three pages")
        for (index, colour) in colours.enumerated() {
            var expected: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) = (0, 0, 0, 0)
            colour.getRed(&expected.r, green: &expected.g, blue: &expected.b, alpha: &expected.a)
            let pixel = try self.centrePixel(of: PDFUtility.generatePageImage(
                try XCTUnwrap(document.page(at: index))
            ))
            XCTAssertEqual(CGFloat(pixel.r) / 255, expected.r, accuracy: 0.15,
                           "page \(index + 1) is not the \(index + 1)th photo — r\(pixel.r) g\(pixel.g) b\(pixel.b)")
            XCTAssertEqual(CGFloat(pixel.g) / 255, expected.g, accuracy: 0.15,
                           "page \(index + 1) is not the \(index + 1)th photo — r\(pixel.r) g\(pixel.g) b\(pixel.b)")
        }
    }

    /// A tall photo and a wide one both have to fit inside the margins rather
    /// than being drawn at their own size, which would put most of the picture
    /// off the page.
    func testThePhotoIsScaledInsideThePage() throws {
        for size in [CGSize(width: 3000, height: 1200), CGSize(width: 1200, height: 3000)] {
            let document = PDFUtility.convertUiImageToPdf(uiImage: self.makePhoto(size: size))
            let page = try XCTUnwrap(document.page(at: 0))
            let bounds = page.bounds(for: .mediaBox)
            XCTAssertEqual(bounds.size.width, K.Misc.PdfPageSize.width, accuracy: 1)
            XCTAssertEqual(bounds.size.height, K.Misc.PdfPageSize.height, accuracy: 1)
            let pixel = try self.centrePixelOfFirstPage(of: document)
            XCTAssertGreaterThan(pixel.r, 150, "\(size) left the page blank")
        }
    }
}
