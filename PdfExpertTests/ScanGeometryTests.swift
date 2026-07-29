//
//  ScanGeometryTests.swift
//  PdfExpertTests
//
//  The maths the scanner stands on: which detections are worth acting on, which
//  corner is which, and the two coordinate conventions a quad has to survive
//  (Vision measures from the bottom left, Core Image from the bottom left in
//  pixels, everything else from the top left).
//
//  Geometry that is off by a flip does not crash — it silently produces mirrored
//  scans — which is exactly the kind of bug a test catches and a screenshot does
//  not.
//

import XCTest
@testable import PdfExpert

final class ScanGeometryTests: XCTestCase {

    // MARK: - Fixtures

    /// A page taking up the middle half of the frame, square on.
    private let centered = ScanQuad(topLeft: CGPoint(x: 0.25, y: 0.25),
                                    topRight: CGPoint(x: 0.75, y: 0.25),
                                    bottomRight: CGPoint(x: 0.75, y: 0.75),
                                    bottomLeft: CGPoint(x: 0.25, y: 0.75))

    // MARK: - Area

    func testAreaOfTheFullFrameIsOne() {
        XCTAssertEqual(ScanQuad.full.area, 1, accuracy: 0.0001)
    }

    func testAreaOfAQuarterFrameQuad() {
        XCTAssertEqual(self.centered.area, 0.25, accuracy: 0.0001)
    }

    // MARK: - Usability

    func testAFullFrameQuadIsUsable() {
        XCTAssertTrue(ScanQuad.full.isUsable)
    }

    func testATinyDetectionIsRejected() {
        let sliver = ScanQuad(topLeft: CGPoint(x: 0.4, y: 0.4),
                              topRight: CGPoint(x: 0.5, y: 0.4),
                              bottomRight: CGPoint(x: 0.5, y: 0.5),
                              bottomLeft: CGPoint(x: 0.4, y: 0.5))
        XCTAssertFalse(sliver.isUsable, "1% of the frame is not a page")
    }

    /// The same shape, drawn on purpose rather than guessed at. The detector's
    /// area floor is an opinion about what is probably a page; a crop the user
    /// dragged into place is not a guess, and rendering has to honour it —
    /// otherwise the page comes back whole and nothing says why.
    func testATinyCropTheUserDrewIsStillRendered() {
        let stamp = ScanQuad(topLeft: CGPoint(x: 0.4, y: 0.4),
                             topRight: CGPoint(x: 0.5, y: 0.4),
                             bottomRight: CGPoint(x: 0.5, y: 0.5),
                             bottomLeft: CGPoint(x: 0.4, y: 0.5))
        XCTAssertFalse(stamp.isUsable, "still not something to propose on its own")
        XCTAssertTrue(stamp.isRenderable, "but perspective correction can crop to it")
    }

    func testAnEdgeCollapsedToNothingIsNotRenderable() {
        let degenerate = ScanQuad(topLeft: CGPoint(x: 0.2, y: 0.2),
                                  topRight: CGPoint(x: 0.205, y: 0.2),
                                  bottomRight: CGPoint(x: 0.8, y: 0.8),
                                  bottomLeft: CGPoint(x: 0.2, y: 0.8))
        XCTAssertFalse(degenerate.isRenderable)
    }

    func testASelfCrossingQuadIsNotRenderableEither() {
        let crossed = ScanQuad(topLeft: CGPoint(x: 0.1, y: 0.1),
                               topRight: CGPoint(x: 0.9, y: 0.9),
                               bottomRight: CGPoint(x: 0.9, y: 0.1),
                               bottomLeft: CGPoint(x: 0.1, y: 0.9))
        XCTAssertFalse(crossed.isRenderable)
    }

    func testASelfCrossingQuadIsNotConvex() {
        // Top-right and bottom-right swapped: the shape folds over itself.
        let crossed = ScanQuad(topLeft: CGPoint(x: 0.1, y: 0.1),
                               topRight: CGPoint(x: 0.9, y: 0.9),
                               bottomRight: CGPoint(x: 0.9, y: 0.1),
                               bottomLeft: CGPoint(x: 0.1, y: 0.9))
        XCTAssertFalse(crossed.isConvex)
        XCTAssertFalse(crossed.isUsable)
    }

    func testAPageShotAtAnAngleIsStillUsable() {
        let skewed = ScanQuad(topLeft: CGPoint(x: 0.18, y: 0.12),
                              topRight: CGPoint(x: 0.86, y: 0.2),
                              bottomRight: CGPoint(x: 0.8, y: 0.9),
                              bottomLeft: CGPoint(x: 0.12, y: 0.82))
        XCTAssertTrue(skewed.isUsable)
    }

    // MARK: - Clamping and labelling

    func testClampingPullsCornersBackIntoTheFrame() {
        let overshooting = ScanQuad(topLeft: CGPoint(x: -0.3, y: -0.2),
                                    topRight: CGPoint(x: 1.4, y: 0),
                                    bottomRight: CGPoint(x: 1.2, y: 1.6),
                                    bottomLeft: CGPoint(x: 0, y: 1.1))
        let clamped = overshooting.clamped()
        for corner in clamped.corners {
            XCTAssertTrue((0...1).contains(corner.x))
            XCTAssertTrue((0...1).contains(corner.y))
        }
    }

    func testCornersAreRelabelledByPositionAfterADrag() {
        // The user has dragged the "top left" handle to the bottom right and the
        // "bottom right" one to the top left; the labels have to follow.
        let dragged = ScanQuad(topLeft: CGPoint(x: 0.8, y: 0.9),
                               topRight: CGPoint(x: 0.9, y: 0.1),
                               bottomRight: CGPoint(x: 0.1, y: 0.2),
                               bottomLeft: CGPoint(x: 0.2, y: 0.8))
        let fixed = dragged.normalizedCorners()
        XCTAssertEqual(fixed.topLeft, CGPoint(x: 0.1, y: 0.2))
        XCTAssertEqual(fixed.topRight, CGPoint(x: 0.9, y: 0.1))
        XCTAssertEqual(fixed.bottomRight, CGPoint(x: 0.8, y: 0.9))
        XCTAssertEqual(fixed.bottomLeft, CGPoint(x: 0.2, y: 0.8))
    }

    func testNormalizingAnAlreadyCorrectQuadChangesNothing() {
        XCTAssertEqual(self.centered.normalizedCorners(), self.centered)
    }

    // MARK: - Full frame

    func testFullFrameIsRecognised() {
        XCTAssertTrue(ScanQuad.full.isFullFrame)
        XCTAssertFalse(self.centered.isFullFrame)
    }

    func testAQuadAThousandthOffIsStillTheFullFrame() {
        // Rounding in the crop editor should not force a pointless correction.
        let almost = ScanQuad(topLeft: CGPoint(x: 0.0005, y: 0),
                              topRight: CGPoint(x: 1, y: 0.001),
                              bottomRight: CGPoint(x: 0.999, y: 1),
                              bottomLeft: CGPoint(x: 0, y: 1))
        XCTAssertTrue(almost.isFullFrame)
    }

    // MARK: - Conversions

    func testPointsAreScaledToTheGivenSize() {
        let points = self.centered.points(in: CGSize(width: 400, height: 800))
        XCTAssertEqual(points[0], CGPoint(x: 100, y: 200))
        XCTAssertEqual(points[2], CGPoint(x: 300, y: 600))
    }

    func testCoreImagePointsFlipTheYAxis() {
        // Core Image measures from the bottom left; the top-left corner of a quad
        // therefore has the *larger* y.
        let points = self.centered.coreImagePoints(in: CGSize(width: 400, height: 800))
        XCTAssertEqual(points.topLeft, CGPoint(x: 100, y: 600))
        XCTAssertEqual(points.bottomLeft, CGPoint(x: 100, y: 200))
        XCTAssertGreaterThan(points.topLeft.y, points.bottomLeft.y)
    }

    // MARK: - Steadiness

    func testCornerDistanceIsZeroAgainstItself() {
        XCTAssertEqual(self.centered.maximumCornerDistance(from: self.centered), 0, accuracy: 0.0001)
    }

    func testCornerDistanceReportsTheWorstCorner() {
        var moved = self.centered
        moved.bottomRight = CGPoint(x: 0.85, y: 0.75)
        XCTAssertEqual(self.centered.maximumCornerDistance(from: moved), 0.1, accuracy: 0.0001)
    }

    // MARK: - Rotation

    func testQuarterTurnsWrapAround() {
        XCTAssertEqual(ScanRotation.none.turnedClockwise(), .quarter)
        XCTAssertEqual(ScanRotation.threeQuarters.turnedClockwise(), .none)
        XCTAssertEqual(ScanRotation.none.turnedCounterclockwise(), .threeQuarters)
    }

    func testOnlyQuarterTurnsSwapTheAxes() {
        XCTAssertTrue(ScanRotation.quarter.swapsAxes)
        XCTAssertTrue(ScanRotation.threeQuarters.swapsAxes)
        XCTAssertFalse(ScanRotation.half.swapsAxes)
        XCTAssertFalse(ScanRotation.none.swapsAxes)
    }

    // MARK: - Preview mapping

    func testAFilledPreviewCropsTheSidesOffAWiderFrame() {
        // A 4:3 frame shown in a tall phone preview: the picture is scaled to the
        // height and the left and right edges fall outside the view, so a quad
        // spanning the whole frame has to land outside it too.
        let points = ScanPreviewGeometry.points(for: .full,
                                                bufferSize: CGSize(width: 1200, height: 1600),
                                                previewSize: CGSize(width: 400, height: 800))
        XCTAssertLessThan(points[0].x, 0)
        XCTAssertGreaterThan(points[1].x, 400)
        XCTAssertEqual(points[0].y, 0, accuracy: 0.001)
        XCTAssertEqual(points[2].y, 800, accuracy: 0.001)
    }

    func testFittedRectLetterboxesRatherThanCrops() {
        let rect = ScanPreviewGeometry.fittedRect(imageSize: CGSize(width: 1000, height: 500),
                                                  in: CGSize(width: 400, height: 400))
        XCTAssertEqual(rect.width, 400, accuracy: 0.001)
        XCTAssertEqual(rect.height, 200, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 100, accuracy: 0.001)
    }
}
