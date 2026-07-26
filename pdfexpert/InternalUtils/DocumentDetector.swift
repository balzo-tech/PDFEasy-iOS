//
//  DocumentDetector.swift
//  PdfExpert
//
//  Finds the page inside a frame, with Vision's document segmentation.
//
//  It is used twice, and the two uses want different things: the live preview
//  needs an answer now and can miss one, while the capture needs the best answer
//  available and can wait a few hundred milliseconds. Both go through the same
//  request — an actor, so the detector is used from the capture queue and the
//  main actor without either having to think about it.
//

import Foundation
import Vision
import CoreImage
import CoreVideo
import ImageIO

actor DocumentDetector {

    /// Vision's own detector. Cheap to hold, expensive to build per frame.
    private let request = DetectDocumentSegmentationRequest()

    /// Below this the observation is a guess about a shadow or a table edge, and
    /// showing it would make the overlay flicker between real pages and noise.
    private static let minimumConfidence: Float = 0.5

    /// The page in a camera frame, or `nil` when there is nothing page-shaped in
    /// view. `orientation` maps the sensor buffer to how the user is holding the
    /// phone; the returned quad is in that same upright space.
    func detect(in pixelBuffer: CVPixelBuffer,
                orientation: CGImagePropertyOrientation) async -> ScanQuad? {
        do {
            let observation = try await self.request.perform(on: pixelBuffer, orientation: orientation)
            return self.quad(from: observation)
        } catch {
            return nil
        }
    }

    /// The page in a still capture. Used to give a photo its initial crop, so
    /// the user usually has nothing to adjust.
    func detect(in image: CIImage) async -> ScanQuad? {
        do {
            let observation = try await self.request.perform(on: image)
            return self.quad(from: observation)
        } catch {
            return nil
        }
    }

    private func quad(from observation: DetectedDocumentObservation?) -> ScanQuad? {
        guard let observation, observation.confidence >= Self.minimumConfidence else { return nil }
        let quad = ScanQuad(observation).clamped().normalizedCorners()
        return quad.isUsable ? quad : nil
    }
}

extension ScanQuad {

    /// Vision measures from the bottom left; the rest of the app measures from
    /// the top left, the way the screen does.
    init(_ observation: some QuadrilateralProviding) {
        func convert(_ point: NormalizedPoint) -> CGPoint {
            CGPoint(x: point.x, y: 1 - point.y)
        }
        self.init(topLeft: convert(observation.topLeft),
                  topRight: convert(observation.topRight),
                  bottomRight: convert(observation.bottomRight),
                  bottomLeft: convert(observation.bottomLeft))
    }

    /// How far this quad's corners have moved from another's, as a fraction of
    /// the frame. The automatic shutter waits for this to stay small.
    func maximumCornerDistance(from other: ScanQuad) -> CGFloat {
        zip(self.corners, other.corners)
            .map { hypot($0.x - $1.x, $0.y - $1.y) }
            .max() ?? 0
    }
}
