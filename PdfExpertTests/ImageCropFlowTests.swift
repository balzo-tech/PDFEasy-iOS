//
//  ImageCropFlowTests.swift
//  PdfExpertTests
//
//  The signature taken from a photo went missing here, twice, and neither time was
//  it the cropping itself: both were about *when* things happen around it.
//

import XCTest
@testable import PdfExpert

@MainActor
final class ImageCropFlowTests: XCTestCase {

    private func makeImage(_ side: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    /// The image handed *in* must not come back out as if it had been cropped: it
    /// travels through the same `image` property the cropper writes its result to.
    func testStartingTheFlowDoesNotReportTheSourceImageAsCropped() {
        let flow = ImageCropFlow()
        var reported: UIImage?
        flow.startFlow(image: self.makeImage(10), onImageCropped: { reported = $0 })
        XCTAssertNil(reported, "the incoming image is not a crop result")
    }

    func testCroppedImageReachesTheCallback() {
        let flow = ImageCropFlow()
        var reported: UIImage?
        flow.startFlow(image: self.makeImage(10), onImageCropped: { reported = $0 })

        let cropped = self.makeImage(4)
        flow.image = cropped
        XCTAssertIdentical(reported, cropped)
    }

    /// The order that broke it. Mantis writes the crop through a binding and
    /// dismisses in the same breath; SwiftUI applies the write on its next pass, so
    /// the view's `onDisappear` runs *before* the image arrives. Dropping the
    /// callback on dismissal therefore threw away the crop — the picker opened, the
    /// sheet came back empty.
    func testCropArrivingAfterTheViewDismissesIsStillDelivered() {
        let flow = ImageCropFlow()
        var reported: UIImage?
        flow.startFlow(image: self.makeImage(10), onImageCropped: { reported = $0 })

        flow.onCropViewDismiss()
        let cropped = self.makeImage(4)
        flow.image = cropped

        XCTAssertIdentical(reported, cropped, "the crop landed after the dismissal and was lost")
    }

    /// A cancelled crop delivers nothing, and leaves nothing armed behind it.
    func testCancelledCropDeliversNothingAndForgetsTheCallback() {
        let flow = ImageCropFlow()
        var calls = 0
        flow.startFlow(image: self.makeImage(10), onImageCropped: { _ in calls += 1 })

        flow.onCropViewDismiss()
        let expectation = self.expectation(description: "the dismissal is processed")
        DispatchQueue.main.async { expectation.fulfill() }
        self.wait(for: [expectation], timeout: 1)

        flow.image = self.makeImage(4)
        XCTAssertEqual(calls, 0, "nothing was cropped, so nobody should be told")
    }
}
