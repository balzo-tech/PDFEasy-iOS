//
//  BackgroundRemovalUtilityTests.swift
//  PdfExpertTests
//
//  The cut-out, checked on the pixels: that what was behind the subject is gone,
//  that what the user chose is there instead, and that the edge treatment never
//  eats into the subject where it touches the frame.
//
//  Vision itself is not asserted on. What its segmentation finds in a fixture
//  drawn by a test is not a promise Apple makes, and a test that depends on it
//  would fail on a machine with no Neural Engine rather than on a real bug. The
//  masks below are drawn here; the one Vision test only checks the shape of what
//  comes back, whichever way it goes.
//

import XCTest
import CoreImage
import CoreImage.CIFilterBuiltins
@testable import PdfExpert

final class BackgroundRemovalUtilityTests: XCTestCase {

    private let size = CGSize(width: 200, height: 200)

    // MARK: - Fixtures

    /// A flat orange photograph — every pixel identifiable once it is composited.
    private func makePhoto() -> CIImage {
        let image = UIGraphicsImageRenderer(size: self.size, format: Self.format).image { context in
            UIColor(red: 1, green: 0.5, blue: 0, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: self.size))
        }
        return CIImage(cgImage: image.cgImage!)
    }

    /// A mask that keeps the middle half and drops everything around it.
    private func makeCentreMask() -> CIImage {
        self.makeMask { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: self.size.width * 0.25, y: self.size.height * 0.25,
                                width: self.size.width * 0.5, height: self.size.height * 0.5))
        }
    }

    /// A mask that keeps everything, right up to the frame.
    private func makeFullMask() -> CIImage {
        self.makeMask { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: self.size))
        }
    }

    private func makeMask(_ draw: (UIGraphicsImageRendererContext) -> Void) -> CIImage {
        let image = UIGraphicsImageRenderer(size: self.size, format: Self.format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: self.size))
            draw(context)
        }
        return BackgroundRemovalUtility.normalizedMask(CIImage(cgImage: image.cgImage!))
    }

    private static var format: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return format
    }

    // MARK: - Reading pixels

    private struct Pixel {
        let r: Int, g: Int, b: Int, a: Int
        var isTransparent: Bool { self.a == 0 }
        var isOpaque: Bool { self.a == 255 }
    }

    /// One pixel of a rendered `CIImage`, in Core Image's coordinates (y up).
    private func pixel(of image: CIImage, at point: CGPoint) throws -> Pixel {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(image,
                       toBitmap: &bytes,
                       rowBytes: 4,
                       bounds: CGRect(x: point.x, y: point.y, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        return Pixel(r: Int(bytes[0]), g: Int(bytes[1]), b: Int(bytes[2]), a: Int(bytes[3]))
    }

    private var centre: CGPoint { CGPoint(x: self.size.width / 2, y: self.size.height / 2) }
    private var corner: CGPoint { CGPoint(x: 4, y: 4) }

    // MARK: - Compositing

    func testTransparentBackgroundKeepsTheSubjectAndDropsTheRest() throws {
        let result = BackgroundRemovalUtility.composite(self.makePhoto(),
                                                        mask: self.makeCentreMask(),
                                                        background: nil)

        let subject = try self.pixel(of: result, at: self.centre)
        XCTAssertTrue(subject.isOpaque, "The subject must survive the cut untouched")
        XCTAssertEqual(subject.r, 255, accuracy: 2)
        XCTAssertEqual(subject.g, 128, accuracy: 3)

        XCTAssertTrue(try self.pixel(of: result, at: self.corner).isTransparent,
                      "Everything outside the mask must come out transparent")
    }

    func testSolidBackgroundReplacesWhatWasBehindTheSubject() throws {
        let result = BackgroundRemovalUtility.composite(self.makePhoto(),
                                                        mask: self.makeCentreMask(),
                                                        background: UIColor.white.cgColor)

        let background = try self.pixel(of: result, at: self.corner)
        XCTAssertTrue(background.isOpaque, "A chosen background is opaque, not a tint over nothing")
        XCTAssertEqual(background.r, 255, accuracy: 2)
        XCTAssertEqual(background.g, 255, accuracy: 2)
        XCTAssertEqual(background.b, 255, accuracy: 2)

        XCTAssertEqual(try self.pixel(of: result, at: self.centre).g, 128, accuracy: 3,
                       "The subject is not tinted by the backdrop behind it")
    }

    /// A grey background arrives as a `CGColor` in a one-component space, which
    /// `CIImage(color:)` renders as black unless it is converted first.
    func testGreyBackgroundIsNotRenderedAsBlack() throws {
        let grey = CGColor(gray: 0.8, alpha: 1)
        let result = BackgroundRemovalUtility.composite(self.makePhoto(),
                                                        mask: self.makeCentreMask(),
                                                        background: grey)

        let background = try self.pixel(of: result, at: self.corner)
        XCTAssertGreaterThan(background.r, 180, "0.8 grey is light, not black")
        XCTAssertEqual(background.r, background.b, accuracy: 2)
    }

    // MARK: - Edge treatment

    func testRefiningKeepsTheImageTheSameSize() {
        let mask = self.makeCentreMask()
        XCTAssertEqual(BackgroundRemovalUtility.refined(mask).extent, mask.extent)
    }

    /// The regression this file exists for: erosion and blur both sample outside
    /// the frame, and without clamping the border reads as empty — which shaves
    /// off any part of the subject that runs to the edge of the photograph.
    func testASubjectThatTouchesTheFrameIsNotEatenByTheEdgeTreatment() throws {
        let result = BackgroundRemovalUtility.composite(self.makePhoto(),
                                                        mask: BackgroundRemovalUtility.refined(self.makeFullMask()),
                                                        background: nil)

        for point in [CGPoint(x: 1, y: 1),
                      CGPoint(x: self.size.width - 2, y: 1),
                      CGPoint(x: 1, y: self.size.height - 2),
                      CGPoint(x: self.size.width - 2, y: self.size.height - 2)] {
            let pixel = try self.pixel(of: result, at: point)
            XCTAssertGreaterThan(pixel.a, 200, "Corner \(point) was eaten by the edge treatment")
        }
    }

    func testRefiningFeathersTheEdgeWithoutTouchingTheMiddle() throws {
        let refined = BackgroundRemovalUtility.refined(self.makeCentreMask())

        XCTAssertEqual(try self.pixel(of: refined, at: self.centre).a, 255, accuracy: 2,
                       "The inside of the mask stays fully opaque")
        // The mask's own border, where the ramp is centred: neither side of it.
        // A value pinned at 0 or 255 here means the edge came out scissored.
        let onTheEdge = try self.pixel(of: refined, at: CGPoint(x: self.size.width * 0.25,
                                                                y: self.size.height / 2))
        XCTAssertGreaterThan(onTheEdge.a, 0, "The edge was cut, not feathered")
        XCTAssertLessThan(onTheEdge.a, 255, "The edge was cut, not feathered")
    }

    /// The dial the halo complaint produced. Turning it up has to pull the edge
    /// *in* — measured on the whole mask, since a choke that only moved one
    /// pixel's value would satisfy a single-point assertion and still leave the
    /// rim of old background that people actually see.
    func testAStrongerEdgeCutsAwayMoreThanAWeakOne() throws {
        let mask = self.makeCentreMask()
        let soft = try self.averageAlpha(of: BackgroundRemovalUtility.refined(mask, strength: 0))
        let mid = try self.averageAlpha(of: BackgroundRemovalUtility.refined(mask, strength: 0.5))
        let hard = try self.averageAlpha(of: BackgroundRemovalUtility.refined(mask, strength: 1))

        XCTAssertLessThan(hard, mid, "Strength 1 must choke harder than 0.5")
        XCTAssertLessThan(mid, soft, "Strength 0.5 must choke harder than 0")
        // And the subject is still there: a dial that erases it at full tilt
        // would pass the two assertions above.
        XCTAssertGreaterThan(hard, 0.15, "The subject was cut away entirely")
    }

    /// Hair is the reason `CIMorphologyMinimum` is gone: a minimum over a disc
    /// deletes everything thinner than the disc outright, so a head came back
    /// wearing a helmet. Thinning a strand is the accepted cost; erasing it at
    /// the default setting is not.
    ///
    /// Three pixels on a 200-pixel fixture is the same proportion as a strand of
    /// hair on a phone photograph, which is the case that produced this test.
    func testAStrandSurvivesTheDefaultSettingAndFadesAsTheDialTurns() throws {
        let strand = self.makeMask { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: self.size.width / 2 - 1, y: 0, width: 3, height: self.size.height))
        }

        let untouched = try self.averageAlpha(of: BackgroundRemovalUtility.refined(strand, strength: 0))
        let standard = try self.averageAlpha(of: BackgroundRemovalUtility.refined(strand, strength: 0.5))

        XCTAssertGreaterThan(standard, 0.002,
                             "A strand was erased at the default setting, not thinned")
        XCTAssertGreaterThan(untouched, standard,
                             "A softer edge has to keep more of the strand than a harder one")
    }

    /// Mean alpha over the whole image, 0…1.
    private func averageAlpha(of image: CIImage) throws -> Double {
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = image.extent
        let output = try XCTUnwrap(filter.outputImage)

        var bytes = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()])
            .render(output,
                    toBitmap: &bytes,
                    rowBytes: 4,
                    bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                    format: .RGBA8,
                    colorSpace: CGColorSpaceCreateDeviceRGB())
        return Double(bytes[3]) / 255
    }

    // MARK: - The backdrops on offer

    /// Transparency only survives PNG, and the tool decides the format from the
    /// style alone. A style that claims transparency and writes JPEG would put
    /// the background back as black — the exact opposite of what was asked.
    func testOnlyTheTransparentStyleIsWrittenAsPng() {
        for style in BackgroundRemovalStyle.allCases {
            XCTAssertEqual(style.isTransparent, style.fileExtension == "png",
                           "\(style.rawValue) writes .\(style.fileExtension) but transparency is \(style.isTransparent)")
        }
    }

    func testEveryOpaqueStyleCarriesAColourAndTransparentCarriesNone() {
        XCTAssertNil(BackgroundRemovalStyle.transparent.cgColor)
        for style in BackgroundRemovalStyle.allCases where style != .transparent {
            XCTAssertNotNil(style.cgColor, "\(style.rawValue) has no colour to put behind the subject")
        }
    }

    // MARK: - Vision

    /// Vision may or may not find a subject in a flat rectangle, and on a
    /// simulator it declines to run at all — the segmentation model has no
    /// inference context there, so this never asserts that a mask *is* produced.
    /// What must hold in every case: a mask that comes back covers exactly the
    /// image it was asked about, and anything else is one of this file's own
    /// errors, which the UI knows how to put into words. A raw Vision error
    /// reaching a caller is the failure being watched for here.
    func testTheVisionMaskEitherCoversTheImageOrFailsWithAKnownError() async throws {
        let photo = self.makePhoto()
        do {
            let mask = try await BackgroundRemovalUtility.subjectMask(for: photo)
            XCTAssertEqual(mask.extent, photo.extent)
        } catch let error as BackgroundRemovalError {
            XCTAssertTrue(error == .noSubjectFound || error == .maskFailed,
                          "Unexpected failure: \(error)")
        }
    }
}
