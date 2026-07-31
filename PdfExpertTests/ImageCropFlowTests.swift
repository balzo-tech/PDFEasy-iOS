//
//  ImageCropFlowTests.swift
//  PdfExpertTests
//
//  The signature taken from a photo went missing here, twice, and neither time was
//  it the cropping itself: both were about *when* things happen around it. Once the
//  cropper was never presented at all, once it was presented and its result raced
//  the cover's dismissal home. What is checked here is that neither depends on
//  timing any more: the crop is delivered because Mantis says so, and a presentation
//  that gets dropped is asked for again.
//

import XCTest
import Combine
@testable import PdfExpert

@MainActor
final class ImageCropFlowTests: XCTestCase {

    /// Short enough to keep the suite quick, long enough to stay in order.
    private static let settleDelay: TimeInterval = 0.02
    private static let checkDelay: TimeInterval = 0.03

    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        self.cancellables.removeAll()
        super.tearDown()
    }

    private func makeFlow() -> ImageCropFlow {
        ImageCropFlow(presentationSettleDelay: Self.settleDelay,
                      presentationCheckDelay: Self.checkDelay)
    }

    private func makeImage(_ side: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    // MARK: - Getting the crop back

    /// The image handed *in* is not a result: nobody is told anything until the
    /// cropper reports one.
    func testStartingTheFlowReportsNothing() {
        let flow = self.makeFlow()
        var reported: UIImage?
        flow.startFlow(image: self.makeImage(10), onImageCropped: { reported = $0 })
        XCTAssertNil(reported, "the incoming image is not a crop result")
    }

    func testCroppedImageReachesTheCallbackAndClosesTheCropper() {
        let flow = self.makeFlow()
        var reported: UIImage?
        flow.startFlow(image: self.makeImage(10), onImageCropped: { reported = $0 })

        let cropped = self.makeImage(4)
        flow.onCropConfirmed(image: cropped)

        XCTAssertIdentical(reported, cropped)
        XCTAssertFalse(flow.cropperShow, "the cropper was left on screen")
    }

    /// The order that used to break it: the cover going away and the crop coming
    /// back are no longer two things racing, because the same call does both.
    func testTheCropIsDeliveredEvenThoughTheCropperIsClosing() {
        let flow = self.makeFlow()
        var showWhenReported: Bool?
        flow.startFlow(image: self.makeImage(10),
                       onImageCropped: { _ in showWhenReported = flow.cropperShow })

        flow.onCropConfirmed(image: self.makeImage(4))

        XCTAssertEqual(showWhenReported, false,
                       "the crop is delivered as the cover closes, not before it is asked to")
    }

    /// A cancelled crop delivers nothing, and leaves nothing armed behind it.
    func testCancelledCropDeliversNothingAndForgetsTheCallback() {
        let flow = self.makeFlow()
        var calls = 0
        flow.startFlow(image: self.makeImage(10), onImageCropped: { _ in calls += 1 })

        flow.onCropCancelled()
        flow.onCropConfirmed(image: self.makeImage(4))

        XCTAssertEqual(calls, 0, "nothing was cropped, so nobody should be told")
        XCTAssertFalse(flow.cropperShow)
    }

    // MARK: - Getting the cropper on screen

    /// Not on the spot: the picker that produced the image is still leaving the
    /// screen, and SwiftUI drops a presentation asked for then.
    func testTheCropperIsAskedForOnceTheScreenIsFree() {
        let flow = self.makeFlow()
        flow.startFlow(image: self.makeImage(10), onImageCropped: { _ in })

        XCTAssertFalse(flow.cropperShow, "the cropper was asked for straight away")
        self.waitForShow(of: flow, toReach: [false, true])
    }

    /// The failure that stuck the whole flow: the presentation was dropped, the flag
    /// stayed `true`, and no later change ever asked SwiftUI for anything again.
    func testADroppedPresentationIsAskedForAgain() {
        let flow = self.makeFlow()
        flow.startFlow(image: self.makeImage(10), onImageCropped: { _ in })

        // The cover never reports appearing, which is what a dropped presentation
        // looks like from here.
        self.waitForShow(of: flow, toReach: [false, true, false, true])
    }

    func testTheCropperIsNotAskedForAgainOnceItIsOnScreen() {
        let flow = self.makeFlow()
        flow.startFlow(image: self.makeImage(10), onImageCropped: { _ in })

        self.waitForShow(of: flow, toReach: [false, true])
        flow.onCropViewAppeared()

        let settled = self.expectation(description: "the retry window passes")
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.checkDelay * 4) { settled.fulfill() }
        self.wait(for: [settled], timeout: 2)

        XCTAssertTrue(flow.cropperShow, "the cropper on screen was closed and asked for again")
    }

    /// A flow abandoned before the cropper arrives asks for nothing.
    func testACancelledFlowStopsAskingForTheCropper() {
        let flow = self.makeFlow()
        flow.startFlow(image: self.makeImage(10), onImageCropped: { _ in })
        flow.onCropCancelled()

        let settled = self.expectation(description: "the presentation window passes")
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.checkDelay * 6) { settled.fulfill() }
        self.wait(for: [settled], timeout: 2)

        XCTAssertFalse(flow.cropperShow, "a flow nobody is waiting on presented itself anyway")
    }

    /// Waits until `cropperShow` has been through exactly the given run of values.
    private func waitForShow(of flow: ImageCropFlow,
                             toReach expected: [Bool],
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        var seen: [Bool] = []
        let reached = self.expectation(description: "cropperShow goes \(expected)")
        reached.assertForOverFulfill = false
        flow.$cropperShow.sink { value in
            seen.append(value)
            if seen == expected { reached.fulfill() }
        }.store(in: &self.cancellables)

        self.wait(for: [reached], timeout: 5)
        XCTAssertEqual(seen, expected, file: file, line: line)
    }
}
