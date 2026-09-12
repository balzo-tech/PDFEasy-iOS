//
//  MemeCaptionTests.swift
//  PdfExpertTests
//
//  The caption engine behind the meme maker, which had no tests at all until the
//  face became something the user picks.
//
//  The invariant worth guarding is the one the canvas and the export both rely
//  on: they must measure the same words with the same font. If `captionFrame`
//  ignored the chosen face while `draw` honoured it, the words would land in one
//  place on screen and another in the file, and nothing would say so.
//

import XCTest
@testable import PdfExpert

final class MemeCaptionTests: XCTestCase {

    private func makeImage(size: CGSize = CGSize(width: 800, height: 800),
                           colour: UIColor = .systemTeal) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            colour.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - The faces

    /// Every face has to answer with a usable font at the size asked for, on
    /// whatever device it runs. The fallbacks exist so a missing family cannot
    /// make the export come back blank.
    func testEveryFaceResolvesToAFontAtTheRequestedSize() {
        for face in ImageCanvasUtility.CaptionFace.allCases {
            let font = face.font(ofSize: 64)
            XCTAssertEqual(font.pointSize, 64, accuracy: 0.01,
                           "\(face.rawValue) did not honour the size")
            XCTAssertFalse(font.familyName.isEmpty, "\(face.rawValue) resolved to a nameless font")
        }
    }

    /// A size of zero or less would make `UIFont` throw; the engine clamps.
    func testAFaceSurvivesADegenerateSize() {
        for face in ImageCanvasUtility.CaptionFace.allCases {
            XCTAssertGreaterThan(face.font(ofSize: 0).pointSize, 0)
            XCTAssertGreaterThan(face.font(ofSize: -10).pointSize, 0)
        }
    }

    /// Impact is the meme face and the default, and an earlier comment in the
    /// engine claimed iOS does not have it. It does.
    func testImpactIsTheDefaultAndIsInstalled() {
        XCTAssertEqual(ImageCanvasUtility.CaptionStyle().face, .impact)
        XCTAssertFalse(UIFont.fontNames(forFamilyName: "Impact").isEmpty,
                       "Impact is no longer on the system; the fallback now carries this face")
    }

    // MARK: - Measuring

    /// The regression this file exists for: the frame must follow the face. Two
    /// faces as different as a condensed grotesque and a serif cannot measure the
    /// same words to the same width.
    func testTheMeasuredFrameFollowsTheChosenFace() {
        let caption = ImageCanvasUtility.Caption(text: "WHEN THE BUILD IS GREEN",
                                                 center: CGPoint(x: 0.5, y: 0.5))
        let box = CGSize(width: 800, height: 800)

        var impact = ImageCanvasUtility.CaptionStyle()
        impact.face = .impact
        var serif = ImageCanvasUtility.CaptionStyle()
        serif.face = .serif

        let one = ImageCanvasUtility.captionFrame(caption, style: impact, in: box)
        let other = ImageCanvasUtility.captionFrame(caption, style: serif, in: box)

        XCTAssertNotEqual(one.size, other.size,
                          "the frame is measured without regard to the face")
    }

    /// Whatever the face and however long the words, a block cannot start
    /// outside the picture — that is what cut "WHEN THE" off the first canvas.
    func testTheFrameStaysInsideThePictureForEveryFace() {
        let box = CGSize(width: 600, height: 900)
        let caption = ImageCanvasUtility.Caption(
            text: "A CAPTION LONG ENOUGH TO WRAP OVER SEVERAL LINES AND THEN SOME",
            center: CGPoint(x: 0.5, y: 0.06),
            scale: 0.14)

        for face in ImageCanvasUtility.CaptionFace.allCases {
            var style = ImageCanvasUtility.CaptionStyle()
            style.face = face
            let frame = ImageCanvasUtility.captionFrame(caption, style: style, in: box)
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "\(face.rawValue) starts left of the picture")
            XCTAssertGreaterThanOrEqual(frame.minY, 0, "\(face.rawValue) starts above the picture")
            XCTAssertLessThanOrEqual(frame.maxX, box.width + 0.5, "\(face.rawValue) runs off the right")
            XCTAssertLessThanOrEqual(frame.width,
                                     box.width * ImageCanvasUtility.captionWidthFraction + 0.5,
                                     "\(face.rawValue) ignored the wrapping width")
        }
    }

    /// An empty block still needs a box, or there is nothing on the canvas to
    /// tap in order to select it.
    func testAnEmptyBlockStillHasAFrame() {
        let frame = ImageCanvasUtility.captionFrame(
            ImageCanvasUtility.Caption(center: CGPoint(x: 0.5, y: 0.5)),
            style: ImageCanvasUtility.CaptionStyle(),
            in: CGSize(width: 400, height: 400))
        XCTAssertGreaterThan(frame.height, 0)
    }

    // MARK: - Alignment

    /// An anchored block takes the margin and ignores `center.x` entirely: that
    /// is what makes "put these words on the left" one control rather than two —
    /// a paragraph setting plus a drag to the matching edge.
    func testAnAlignedBlockTakesTheMarginWhateverItsCentreSays() {
        let box = CGSize(width: 800, height: 800)
        let style = ImageCanvasUtility.CaptionStyle()
        let inset = box.width * (1 - ImageCanvasUtility.captionWidthFraction) / 2

        for centreX in [0.2, 0.5, 0.8] {
            var caption = ImageCanvasUtility.Caption(text: "LEFT",
                                                     center: CGPoint(x: centreX, y: 0.5))
            caption.alignment = .leading
            let leading = ImageCanvasUtility.captionFrame(caption, style: style, in: box)
            XCTAssertEqual(leading.minX, inset, accuracy: 0.5,
                           "a left-aligned block moved with its centre")

            caption.alignment = .trailing
            let trailing = ImageCanvasUtility.captionFrame(caption, style: style, in: box)
            XCTAssertEqual(trailing.maxX, box.width - inset, accuracy: 0.5,
                           "a right-aligned block moved with its centre")
        }
    }

    /// And a centred one still goes where it was dragged — the default is the
    /// meme format's own and nothing about it changed.
    func testACentredBlockStillFollowsItsCentre() {
        let box = CGSize(width: 800, height: 800)
        let caption = ImageCanvasUtility.Caption(text: "MIDDLE", center: CGPoint(x: 0.3, y: 0.5))
        let frame = ImageCanvasUtility.captionFrame(caption, style: ImageCanvasUtility.CaptionStyle(),
                                                    in: box)
        XCTAssertEqual(frame.midX, box.width * 0.3, accuracy: 0.5)
    }

    /// Wherever it is anchored, it stays on the picture: the same invariant the
    /// centred case has, checked on the two cases that bypass `center.x`.
    func testAnAlignedBlockStaysOnThePicture() {
        let box = CGSize(width: 500, height: 700)
        for alignment in ImageCanvasUtility.CaptionAlignment.allCases {
            var caption = ImageCanvasUtility.Caption(
                text: "A CAPTION LONG ENOUGH TO WRAP OVER SEVERAL LINES AND THEN SOME",
                center: CGPoint(x: 0.92, y: 0.5),
                scale: 0.14)
            caption.alignment = alignment
            let frame = ImageCanvasUtility.captionFrame(caption,
                                                        style: ImageCanvasUtility.CaptionStyle(),
                                                        in: box)
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "\(alignment.rawValue) starts off the picture")
            XCTAssertLessThanOrEqual(frame.maxX, box.width + 0.5, "\(alignment.rawValue) runs off the right")
        }
    }

    /// The canvas and the export have to agree about alignment as they do about
    /// everything else, and they can only do that by both reading the caption.
    /// A block set to the left must not draw the same picture as one set to the
    /// right.
    func testAlignmentReachesTheExportedPicture() {
        let source = self.makeImage()
        var left = ImageCanvasUtility.Caption(text: "HELLO", center: CGPoint(x: 0.5, y: 0.5))
        left.alignment = .leading
        var right = left
        right.alignment = .trailing

        let one = ImageCanvasUtility.captioned(source, captions: [left],
                                               style: ImageCanvasUtility.CaptionStyle())
        let other = ImageCanvasUtility.captioned(source, captions: [right],
                                                 style: ImageCanvasUtility.CaptionStyle())
        XCTAssertNotEqual(one.pngData(), other.pngData(),
                          "alignment never reached the file")
    }

    // MARK: - Drawing

    /// Blank blocks are placeholders on the canvas and nothing at all in the
    /// file: the picture that comes back has to be the one that went in.
    func testBlankCaptionsAreNotDrawn() {
        let source = self.makeImage()
        let result = ImageCanvasUtility.captioned(
            source,
            captions: [ImageCanvasUtility.Caption(center: CGPoint(x: 0.5, y: 0.12)),
                       ImageCanvasUtility.Caption(text: "   ", center: CGPoint(x: 0.5, y: 0.88))],
            style: ImageCanvasUtility.CaptionStyle())
        XCTAssertEqual(result.pngData(), source.pngData(),
                       "an empty block left a mark on the exported picture")
    }

    /// And a block with words in it does change the picture, whichever face is
    /// chosen — the check that the fallbacks actually draw something.
    func testEveryFaceDrawsSomething() {
        let source = self.makeImage()
        for face in ImageCanvasUtility.CaptionFace.allCases {
            var style = ImageCanvasUtility.CaptionStyle()
            style.face = face
            let result = ImageCanvasUtility.captioned(
                source,
                captions: [ImageCanvasUtility.Caption(text: "HELLO",
                                                      center: CGPoint(x: 0.5, y: 0.5))],
                style: style)
            XCTAssertNotEqual(result.pngData(), source.pngData(),
                              "\(face.rawValue) drew nothing at all")
            XCTAssertEqual(result.size, source.size,
                           "\(face.rawValue) changed the size of the picture")
        }
    }

    /// The export runs at the picture's own resolution and the canvas at a few
    /// hundred points; the caption has to land in the same *relative* place in
    /// both, or what is dragged is not what is shared.
    func testTheFrameIsProportionalToThePicture() {
        let caption = ImageCanvasUtility.Caption(text: "SAME PLACE",
                                                 center: CGPoint(x: 0.3, y: 0.7))
        let style = ImageCanvasUtility.CaptionStyle()
        let small = ImageCanvasUtility.captionFrame(caption, style: style,
                                                    in: CGSize(width: 300, height: 400))
        let large = ImageCanvasUtility.captionFrame(caption, style: style,
                                                    in: CGSize(width: 1500, height: 2000))

        XCTAssertEqual(small.midX / 300, large.midX / 1500, accuracy: 0.02,
                       "the block drifts sideways when the picture is bigger")
        XCTAssertEqual(small.midY / 400, large.midY / 2000, accuracy: 0.02,
                       "the block drifts down when the picture is bigger")
    }
}
