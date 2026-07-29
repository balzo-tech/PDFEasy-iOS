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
                           orientation: UIImage.Orientation = .up) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let flat = renderer.image { context in
            UIColor.red.setFill()
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
    func testTheCopyTheEditorDrawsIsNotBlank() throws {
        let document = PDFUtility.convertUiImageToPdf(uiImage: self.makePhoto(orientation: .right))
        let page = try XCTUnwrap(document.page(at: 0))
        let copy = try XCTUnwrap(page.copy() as? PDFPage, "a page has to be copyable")

        let image = PDFUtility.generatePageImage(copy)
        let holder = PDFDocument()
        holder.insert(copy, at: 0)

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
        XCTAssertGreaterThan(Int(pixel[0]), 150,
                             "the page the editor draws is blank — r\(pixel[0]) g\(pixel[1]) b\(pixel[2])")
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
