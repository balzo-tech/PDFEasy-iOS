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
