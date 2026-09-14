//
//  ImageCompressUtilityTests.swift
//  PdfExpertTests
//
//  The promises "Compress images" makes, checked on the bytes that come out:
//  that the file gets smaller, that the picture is never enlarged, that a
//  transparent PNG does not come back on a black background, and that the
//  location the photograph was taken at is not carried into the copy the user is
//  about to send to somebody.
//
//  The fixtures are drawn here rather than shipped: a photograph in the bundle
//  would make these tests about that photograph.
//

import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import PdfExpert

final class ImageCompressUtilityTests: XCTestCase {

    // MARK: - Fixtures

    private static var format: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return format
    }

    /// Noise, not a flat fill: a single colour compresses to almost nothing at
    /// any quality, which would make every assertion below pass for the wrong
    /// reason. This is closer to what a camera produces.
    private func makePhoto(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size, format: Self.format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            var generator = SystemRandomNumberGenerator()
            for x in stride(from: 0, to: width, by: 4) {
                for y in stride(from: 0, to: height, by: 4) {
                    UIColor(red: .random(in: 0...1, using: &generator),
                            green: .random(in: 0...1, using: &generator),
                            blue: .random(in: 0...1, using: &generator),
                            alpha: 1).setFill()
                    context.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
    }

    /// A cut-out: an opaque square in the middle of nothing at all.
    private func makeTransparentImage(side: Int) -> UIImage {
        let size = CGSize(width: side, height: side)
        let format = Self.format
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: side / 4, y: side / 4, width: side / 2, height: side / 2))
        }
    }

    private func write(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)")
        try data.write(to: url)
        self.addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    // MARK: - It actually shrinks

    func testCompressingAPhotographMakesItSmaller() throws {
        let original = try XCTUnwrap(self.makePhoto(width: 2000, height: 1500).jpegData(compressionQuality: 1.0))

        let result = try XCTUnwrap(ImageCompressUtility.compress(data: original,
                                                                 quality: .balanced,
                                                                 size: .medium))

        XCTAssertTrue(result.isSmaller, "A full-quality 3 MP photograph should shrink at Medium/Balanced")
        XCTAssertEqual(result.originalByteCount, original.count)
        XCTAssertEqual(result.compressedByteCount, result.data.count)
        XCTAssertGreaterThan(result.savedFraction, 0)
    }

    /// The three quality steps have to be ordered, or the dial means nothing.
    func testHarderQualityProducesASmallerFile() throws {
        let original = try XCTUnwrap(self.makePhoto(width: 1600, height: 1200).jpegData(compressionQuality: 1.0))

        let light = try XCTUnwrap(ImageCompressUtility.compress(data: original, quality: .light, size: .original))
        let balanced = try XCTUnwrap(ImageCompressUtility.compress(data: original, quality: .balanced, size: .original))
        let maximum = try XCTUnwrap(ImageCompressUtility.compress(data: original, quality: .maximum, size: .original))

        XCTAssertLessThan(balanced.compressedByteCount, light.compressedByteCount)
        XCTAssertLessThan(maximum.compressedByteCount, balanced.compressedByteCount)
    }

    // MARK: - Resolution

    func testSizeBoundsTheLongestSide() throws {
        let original = try XCTUnwrap(self.makePhoto(width: 3000, height: 2000).jpegData(compressionQuality: 0.9))

        let result = try XCTUnwrap(ImageCompressUtility.compress(data: original, quality: .balanced, size: .small))

        XCTAssertEqual(max(result.pixelSize.width, result.pixelSize.height), 1024)
        // The aspect ratio survives: 3:2 in, 3:2 out, give or take a rounded pixel.
        XCTAssertEqual(result.pixelSize.width / result.pixelSize.height, 1.5, accuracy: 0.01)
    }

    func testOriginalSizeKeepsTheDimensions() throws {
        let original = try XCTUnwrap(self.makePhoto(width: 900, height: 600).jpegData(compressionQuality: 0.9))

        let result = try XCTUnwrap(ImageCompressUtility.compress(data: original, quality: .balanced, size: .original))

        XCTAssertEqual(result.pixelSize, CGSize(width: 900, height: 600))
    }

    /// The one that would be embarrassing: a small picture asked to be "Large"
    /// must not come back enlarged — heavier than it went in, and no better.
    func testASmallPictureIsNeverEnlarged() throws {
        let original = try XCTUnwrap(self.makePhoto(width: 800, height: 600).jpegData(compressionQuality: 0.9))

        let result = try XCTUnwrap(ImageCompressUtility.compress(data: original, quality: .light, size: .large))

        XCTAssertEqual(result.pixelSize, CGSize(width: 800, height: 600))
    }

    // MARK: - Transparency

    func testATransparentPngComesBackOnWhiteRatherThanBlack() throws {
        let original = try XCTUnwrap(self.makeTransparentImage(side: 400).pngData())

        let result = try XCTUnwrap(ImageCompressUtility.compress(data: original, quality: .light, size: .original))

        let image = try XCTUnwrap(UIImage(data: result.data))
        let corner = try XCTUnwrap(self.colour(of: image, at: CGPoint(x: 5, y: 5)))
        // The corner was transparent. Dropping the alpha channel would make it
        // black; compositing makes it white.
        XCTAssertGreaterThan(corner.red, 0.9)
        XCTAssertGreaterThan(corner.green, 0.9)
        XCTAssertGreaterThan(corner.blue, 0.9)
    }

    // MARK: - What is not carried over

    func testLocationMetadataIsNotCopiedIntoTheResult() throws {
        let original = try XCTUnwrap(self.makePhoto(width: 600, height: 400).jpegData(compressionQuality: 0.9))
        let withGps = try XCTUnwrap(self.addingGpsMetadata(to: original))
        XCTAssertNotNil(self.gpsDictionary(in: withGps), "The fixture itself must carry GPS, or this proves nothing")

        let result = try XCTUnwrap(ImageCompressUtility.compress(data: withGps, quality: .balanced, size: .medium))

        XCTAssertNil(self.gpsDictionary(in: result.data))
    }

    // MARK: - Reading a file

    func testCompressingFromDiskReportsTheFileSizeAsTheOriginal() throws {
        let data = try XCTUnwrap(self.makePhoto(width: 1200, height: 900).jpegData(compressionQuality: 1.0))
        let url = try self.write(data, name: "photo.jpg")

        let result = try XCTUnwrap(ImageCompressUtility.compress(url: url, quality: .balanced, size: .medium))

        XCTAssertEqual(result.originalByteCount, data.count)
        XCTAssertTrue(result.isSmaller)
    }

    func testPixelSizeIsReadWithoutDecoding() throws {
        let data = try XCTUnwrap(self.makePhoto(width: 1234, height: 567).jpegData(compressionQuality: 0.8))
        let url = try self.write(data, name: "sized.jpg")

        XCTAssertEqual(ImageCompressUtility.pixelSize(url: url), CGSize(width: 1234, height: 567))
    }

    func testThumbnailIsBoundedToWhatWasAskedFor() throws {
        let data = try XCTUnwrap(self.makePhoto(width: 2000, height: 1000).jpegData(compressionQuality: 0.8))
        let url = try self.write(data, name: "thumb.jpg")

        let thumbnail = try XCTUnwrap(ImageCompressUtility.thumbnail(url: url, maxPixelSize: 240))

        XCTAssertEqual(max(thumbnail.size.width, thumbnail.size.height), 240)
    }

    func testAFileThatIsNotAnImageIsRefusedRatherThanGuessedAt() throws {
        let url = try self.write(Data("this is not a picture".utf8), name: "notes.txt")

        XCTAssertNil(ImageCompressUtility.compress(url: url, quality: .balanced, size: .medium))
        XCTAssertNil(ImageCompressUtility.pixelSize(url: url))
    }

    // MARK: - The numbers the UI shows

    func testSavedFractionIsZeroWhenTheResultIsNotSmaller() {
        let result = ImageCompressionResult(data: Data(count: 120),
                                            pixelSize: CGSize(width: 10, height: 10),
                                            originalByteCount: 100)

        XCTAssertFalse(result.isSmaller)
        XCTAssertEqual(result.savedFraction, 0, "A heavier result must never be reported as a saving")
    }

    func testSavedFractionIsTheShareOfTheFileThatWentAway() {
        let result = ImageCompressionResult(data: Data(count: 250),
                                            pixelSize: CGSize(width: 10, height: 10),
                                            originalByteCount: 1000)

        XCTAssertEqual(result.savedFraction, 0.75, accuracy: 0.0001)
    }

    /// The tracking values are asserted because renaming one later does not
    /// correct the past: it splits the series in two.
    func testTrackingValuesAreStable() {
        XCTAssertEqual(ImageCompressionQuality.light.trackingParameterValue, "light")
        XCTAssertEqual(ImageCompressionQuality.balanced.trackingParameterValue, "balanced")
        XCTAssertEqual(ImageCompressionQuality.maximum.trackingParameterValue, "maximum")
        XCTAssertEqual(ImageCompressionSize.original.trackingParameterValue, "original")
        XCTAssertEqual(ImageCompressionSize.large.trackingParameterValue, "large")
        XCTAssertEqual(ImageCompressionSize.medium.trackingParameterValue, "medium")
        XCTAssertEqual(ImageCompressionSize.small.trackingParameterValue, "small")
    }

    func testTheQualityStepsAreOrdered() {
        XCTAssertGreaterThan(ImageCompressionQuality.light.jpegQuality,
                             ImageCompressionQuality.balanced.jpegQuality)
        XCTAssertGreaterThan(ImageCompressionQuality.balanced.jpegQuality,
                             ImageCompressionQuality.maximum.jpegQuality)
    }

    func testTheSizeStepsAreOrdered() throws {
        XCTAssertNil(ImageCompressionSize.original.maxPixelSize)
        let large = try XCTUnwrap(ImageCompressionSize.large.maxPixelSize)
        let medium = try XCTUnwrap(ImageCompressionSize.medium.maxPixelSize)
        let small = try XCTUnwrap(ImageCompressionSize.small.maxPixelSize)
        XCTAssertGreaterThan(large, medium)
        XCTAssertGreaterThan(medium, small)
    }

    // MARK: - Helpers

    private func colour(of image: UIImage, at point: CGPoint) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        guard let cgImage = image.cgImage else { return nil }
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let context = CGContext(data: &pixel,
                                      width: 1,
                                      height: 1,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.draw(cgImage,
                     in: CGRect(x: -point.x, y: -(CGFloat(cgImage.height) - point.y - 1),
                                width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        return (CGFloat(pixel[0]) / 255, CGFloat(pixel[1]) / 255, CGFloat(pixel[2]) / 255)
    }

    private func addingGpsMetadata(to data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else { return nil }
        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 45.4642,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 9.19,
            kCGImagePropertyGPSLongitudeRef: "E"
        ]
        CGImageDestinationAddImageFromSource(destination, source, 0,
                                             [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private func gpsDictionary(in data: Data) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
    }
}
