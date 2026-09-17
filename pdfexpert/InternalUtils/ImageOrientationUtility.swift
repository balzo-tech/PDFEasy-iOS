//
//  ImageOrientationUtility.swift
//  PdfExpert
//
//  Turns a photographed document the right way up before it becomes a page.
//
//  208 people a month rotate pages by hand, 1,090 times between them — more
//  users than every utility tool in the catalog put together. They are not
//  choosing to rotate anything: a phone writes the orientation it was held at,
//  and a sheet of paper photographed from above has no orientation to write, so
//  the page arrives on its side and the first thing to do with it is turn it.
//
//  Vision already knows which way up the writing is. Reading the picture at each
//  of the four quarter turns and keeping the one that yields the most text is
//  enough to tell — and on a picture with no text in it (a photograph of a
//  person, a meme, a landscape) every turn yields nothing, no turn wins, and the
//  image is handed back exactly as it came in.
//

import Foundation
import UIKit
import Vision

enum ImageOrientationUtility {

    /// Long edge of the bitmap the detection runs on. Recognition only has to
    /// count words here, not read them, so this is far below what OCR would want.
    private static let analysisMaxDimension: CGFloat = 1000

    /// Enough recognized characters at the upright reading to stop looking. A
    /// page that is already the right way up is the common case and should cost
    /// one pass, not four.
    private static let confidentUprightCharacterCount: Int = 40

    /// Below this, whatever was recognized is noise — a logo, a number plate, the
    /// writing on a t-shirt — and not a reason to turn someone's photograph.
    private static let minimumCharacterCount: Int = 12

    /// How much better a turn has to read than the upright one before the image
    /// is turned. A document read sideways scores near zero, so the real gap is
    /// enormous; this only guards the ambiguous middle.
    private static let winningMargin: Double = 1.5

    /// Minimum Vision confidence for a line to be counted at all.
    private static let minimumConfidence: Float = 0.3

    /// The image, turned upright when the writing on it says so. Off the main
    /// thread: this is Vision, and it is called while a document is being built.
    static func uprighted(_ image: UIImage) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            Self.uprightedSynchronously(image)
        }.value
    }

    static func uprightedSynchronously(_ image: UIImage) -> UIImage {
        guard let analysed = Self.analysisImage(from: image)?.cgImage else { return image }

        let upright = Self.characterCount(in: analysed, orientation: .up)
        if upright >= Self.confidentUprightCharacterCount { return image }

        var best: (rotation: CGImagePropertyOrientation, count: Int) = (.up, upright)
        // `.right` reads an image whose top is on the left, and so on: these are
        // the three quarter turns, expressed the way Vision expresses them.
        for orientation in [CGImagePropertyOrientation.right, .down, .left] {
            let count = Self.characterCount(in: analysed, orientation: orientation)
            if count > best.count {
                best = (orientation, count)
            }
        }

        guard best.rotation != .up,
              best.count >= Self.minimumCharacterCount,
              Double(best.count) >= Double(max(upright, 1)) * Self.winningMargin else { return image }

        return Self.rotated(image, by: Self.radians(for: best.rotation)) ?? image
    }

    // MARK: - Reading

    private static func characterCount(in cgImage: CGImage,
                                       orientation: CGImagePropertyOrientation) -> Int {
        let request = VNRecognizeTextRequest()
        // Counting, not transcribing: the fast path is several times quicker and
        // finds the same amount of writing.
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = OcrUtility.defaultLanguages

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return 0
        }
        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        return observations.reduce(into: 0) { total, observation in
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= Self.minimumConfidence else { return }
            total += candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).count
        }
    }

    // MARK: - Turning

    /// The turn that puts an image read at `orientation` back upright.
    private static func radians(for orientation: CGImagePropertyOrientation) -> CGFloat {
        switch orientation {
        case .right: return .pi / 2
        case .down: return .pi
        case .left: return -.pi / 2
        default: return 0
        }
    }

    private static func analysisImage(from image: UIImage) -> UIImage? {
        guard let fixed = image.fixedOrientation() else { return image.cgImage == nil ? nil : image }
        let longEdge = max(fixed.size.width, fixed.size.height)
        guard longEdge > Self.analysisMaxDimension else { return fixed }
        return fixed.scaledImage(scaleFactor: Self.analysisMaxDimension / longEdge) ?? fixed
    }

    private static func rotated(_ image: UIImage, by radians: CGFloat) -> UIImage? {
        guard let fixed = image.fixedOrientation(), let cgImage = fixed.cgImage else { return nil }
        let size = CGSize(width: fixed.size.width, height: fixed.size.height)
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral
            .size

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = fixed.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: rotatedSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            cg.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            cg.rotate(by: radians)
            // Core Graphics draws bottom-up; flipping here keeps the picture the
            // right way round rather than mirrored.
            cg.scaleBy(x: 1, y: -1)
            cg.draw(cgImage,
                    in: CGRect(x: -size.width / 2,
                               y: -size.height / 2,
                               width: size.width,
                               height: size.height))
        }
    }
}
