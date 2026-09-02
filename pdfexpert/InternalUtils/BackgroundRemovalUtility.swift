//
//  BackgroundRemovalUtility.swift
//  PdfExpert
//
//  Cuts the subject out of a photograph and puts something else behind it.
//
//  The mask comes from Vision's `GenerateForegroundInstanceMaskRequest` — the
//  same segmentation behind "lift subject from background" in Photos. It runs
//  on-device, costs nothing per image and ships no model of its own, which is
//  why it is here rather than a converted U²-Net or RMBG: those add tens of
//  megabytes to the binary (and RMBG's licence forbids selling the result)
//  without cutting hair any better.
//
//  The work is split in three so only the first step needs a Neural Engine:
//  `subjectMask` asks Vision, `refined` shapes the edge, `composite` blends.
//  The last two are ordinary Core Image and are what the tests exercise, since
//  what Vision finds in a synthetic fixture is not something to assert on.
//

import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

enum BackgroundRemovalError: LocalizedError, Equatable {
    /// Vision ran and found nothing to lift — an empty wall, a document, a
    /// texture. Not a failure of the code, and the UI says so in those words:
    /// "try again" is the wrong advice for a photograph that has no subject in
    /// it, and the user is the only one who can fix that.
    case noSubjectFound
    case maskFailed
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .noSubjectFound:
            return String(localized: "No subject was found in this photo. It works best with a person, an animal or an object in the foreground.")
        case .maskFailed, .renderFailed:
            return String(localized: "Internal Error. Please try again later")
        }
    }
}

enum BackgroundRemovalUtility {

    /// How far the mask is blurred before its edge is re-cut, as a fraction of
    /// the image's longest side: the first number at strength 0, the second at
    /// strength 1.
    ///
    /// Vision's mask has a staircase along any diagonal. Blurring turns the
    /// steps into a ramp, and moving the threshold along that ramp is what
    /// pulls the edge in. **The width of the ramp is the choke's reach**: a
    /// one-pixel blur cannot pull the edge in by two pixels no matter where the
    /// threshold goes. So the blur grows with the dial — that is what makes the
    /// right-hand end of the slider actually remove a halo, and what costs the
    /// finest strands when it does. There is no setting that does both; that is
    /// why the choice is the user's.
    private static let softenFractionAtZero: CGFloat = 0.0002
    private static let softenFractionAtOne: CGFloat = 0.0020
    /// Never less than a whole pixel: below roughly a thousand pixels wide the
    /// fraction rounds to nothing and Core Image skips the blur entirely, so a
    /// screenshot came back with the raw mask edge while a full-resolution photo
    /// did not, for no reason the user could see.
    private static let minimumRadius: CGFloat = 1

    /// How far the threshold moves into the subject at full strength, and how
    /// wide the ramp around it is.
    ///
    /// **This is what removes the halo, and why the earlier `CIMorphologyMinimum`
    /// is gone.** Vision's mask runs a hair wide, so the outermost pixels of a
    /// cut-out are part old background — a bright rim on a dark backdrop, a dark
    /// one on a bright backdrop. Morphological erosion shaves those off, but it
    /// takes a *minimum over a disc*, which deletes any structure thinner than
    /// the disc: individual strands of hair vanish and the head comes back
    /// wearing a helmet. Moving the alpha threshold instead pulls the edge in by
    /// the same amount while every partial value in between survives, so hair
    /// stays hair and only the contaminated fringe goes.
    private static let maximumChoke: CGFloat = 0.32
    /// Ramp width, from softest to hardest. Wide is forgiving on hair, narrow is
    /// clean on a hard-edged object.
    private static let softestRamp: CGFloat = 0.55
    private static let hardestRamp: CGFloat = 0.16

    // MARK: - The mask
    //
    // There is no one-shot `removeBackground(photo:)` here on purpose. The mask
    // is the expensive half and it does not change when the backdrop does, so
    // every caller keeps it and re-blends — a convenience wrapper would be the
    // slow way to do the same thing, sitting next to the fast one.

    /// The subject's silhouette, at the source image's own resolution and in its
    /// own coordinate space, carried in every channel including alpha.
    ///
    /// Vision hands back a one-component buffer, and Core Image's blend reads a
    /// mask's *alpha*. Spreading the single component across RGB **and** A makes
    /// the mask mean the same thing whichever channel a filter downstream looks
    /// at, which is one class of silent bug removed: a mask that is opaque
    /// everywhere blends nothing and looks exactly like a tool that did nothing.
    static func subjectMask(for image: CIImage) async throws -> CIImage {
        let handler = ImageRequestHandler(image)
        let found: InstanceMaskObservation?
        do {
            found = try await handler.perform(GenerateForegroundInstanceMaskRequest())
        } catch {
            // Vision's own errors are not for showing: on a simulator the model
            // has no inference context at all ("Could not create inference
            // context"), which is an environment saying no rather than anything
            // about this photograph. The caller gets one failure to explain.
            throw BackgroundRemovalError.maskFailed
        }
        guard let observation = found, !observation.allInstances.isEmpty else {
            throw BackgroundRemovalError.noSubjectFound
        }

        let buffer: CVPixelBuffer
        do {
            buffer = try observation.generateScaledMask(for: observation.allInstances,
                                                        scaledToImageFrom: handler)
        } catch {
            throw BackgroundRemovalError.maskFailed
        }

        let mask = CIImage(cvPixelBuffer: buffer)
        return self.normalizedMask(self.aligned(mask, to: image))
    }

    /// Re-cuts the mask's edge: blur it into a ramp, then choose where along that
    /// ramp the subject ends.
    ///
    /// `strength` is the one dial. At 0 the edge is left soft and wide, which
    /// keeps every wisp of hair and some of the background with it; at 1 it is
    /// pulled well inside and cut narrow, which loses the finest strands and
    /// takes the halo with them. The right answer depends on the photograph —
    /// hair against a bright wall wants more than a phone held against a desk —
    /// which is why it is on screen rather than baked in here.
    ///
    /// `clampedToExtent` before the blur and a crop after: it samples outside
    /// the image, and without the clamp the border reads as transparent black,
    /// which eats the subject wherever it touches the frame — the usual "her
    /// shoulder is missing" report.
    static func refined(_ mask: CIImage, strength: CGFloat = Self.defaultEdgeStrength) -> CIImage {
        let extent = mask.extent
        guard !extent.isEmpty, !extent.isInfinite,
              extent.width.isFinite, extent.height.isFinite else { return mask }

        let strength = min(max(strength, 0), 1)
        let longestSide = max(extent.width, extent.height)

        let soften = self.softenFractionAtZero
            + (self.softenFractionAtOne - self.softenFractionAtZero) * strength
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = mask.clampedToExtent()
        blur.radius = Float(max(self.minimumRadius, longestSide * soften))
        let softened = (blur.outputImage ?? mask).cropped(to: extent)

        // α' = (α - threshold) / ramp + 0.5, clamped. A slope on the alpha
        // channel and a matching bias: Core Image has no curve filter that works
        // on alpha alone, and a colour matrix does exactly this in one pass.
        let threshold = 0.5 + self.maximumChoke * strength
        let ramp = max(self.softestRamp + (self.hardestRamp - self.softestRamp) * strength, 0.01)
        let slope = 1 / ramp
        let bias = 0.5 - threshold * slope

        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = softened
        matrix.rVector = CIVector(x: slope, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: slope, y: 0, z: 0, w: 0)
        matrix.bVector = CIVector(x: slope, y: 0, z: 0, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: slope)
        matrix.biasVector = CIVector(x: bias, y: bias, z: bias, w: bias)
        guard let ramped = matrix.outputImage else { return softened }

        // The matrix runs values past 0 and 1 by design; unclamped they come out
        // of the blend as glowing or inverted pixels.
        let clamp = CIFilter.colorClamp()
        clamp.inputImage = ramped
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        return (clamp.outputImage ?? ramped).cropped(to: extent)
    }

    /// Where the dial starts. Enough choke to kill the halo on an ordinary
    /// portrait without turning hair into a silhouette.
    static let defaultEdgeStrength: CGFloat = 0.5

    // MARK: - Compositing

    /// Puts `background` behind the masked subject. A `nil` background leaves
    /// transparency.
    static func composite(_ image: CIImage, mask: CIImage, background: CGColor?) -> CIImage {
        let extent = image.extent
        let backdrop: CIImage
        if let background, let color = self.ciColor(from: background) {
            backdrop = CIImage(color: color).cropped(to: extent)
        } else {
            // Not `CIImage.empty()`: that one has an empty extent, and a blend
            // against it renders nothing at all outside the subject on some
            // paths. A clear colour cropped to the frame is unambiguous.
            backdrop = CIImage(color: .clear).cropped(to: extent)
        }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = image
        blend.backgroundImage = backdrop
        blend.maskImage = self.aligned(mask, to: image)
        return (blend.outputImage ?? image).cropped(to: extent)
    }

    // MARK: - Geometry

    /// Scales and moves `mask` onto `image`'s extent.
    ///
    /// Vision's scaled mask normally matches already; it does not when the
    /// source went through Core Image first (a crop, a straightened scan), and a
    /// mask that is off by a few pixels shows up as a subject with a sliced edge
    /// rather than as an error.
    private static func aligned(_ mask: CIImage, to image: CIImage) -> CIImage {
        let target = image.extent
        let source = mask.extent
        guard !source.isEmpty, !target.isEmpty else { return mask }
        guard source != target else { return mask }

        let scale = CGAffineTransform(scaleX: target.width / source.width,
                                      y: target.height / source.height)
        let scaled = mask.transformed(by: scale)
        return scaled.transformed(by: CGAffineTransform(translationX: target.origin.x - scaled.extent.origin.x,
                                                        y: target.origin.y - scaled.extent.origin.y))
    }

    /// A Core Image colour for any `CGColor`.
    ///
    /// Converted to sRGB first: a grey or a P3 swatch from a colour picker is not
    /// an RGB colour, and `CIImage(color:)` fills the frame with black when
    /// handed one.
    private static func ciColor(from color: CGColor) -> CIColor? {
        if color.colorSpace?.model == .rgb { return CIColor(cgColor: color) }
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil) else {
            return nil
        }
        return CIColor(cgColor: converted)
    }

    #if DEBUG
    /// An oval where the subject would be.
    ///
    /// Only for looking at the screen on a simulator, where Vision refuses to
    /// run at all ("Could not create inference context") and every photo would
    /// otherwise end in the same error alert. It is never a fallback on a
    /// device: a made-up silhouette saved to someone's photo library would be a
    /// worse answer than the error.
    static func debugPlaceholderMask(for image: CIImage) -> CIImage {
        let extent = image.extent
        let renderer = UIGraphicsImageRenderer(size: extent.size,
                                               format: {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return format
        }())
        let drawn = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: extent.size))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: extent.insetBy(dx: extent.width * 0.2,
                                                             dy: extent.height * 0.15)
                .offsetBy(dx: -extent.origin.x, dy: -extent.origin.y))
        }
        guard let cgImage = drawn.cgImage else { return image }
        return self.normalizedMask(CIImage(cgImage: cgImage).transformed(
            by: CGAffineTransform(translationX: extent.origin.x, y: extent.origin.y)))
    }
    #endif

    /// Copies a mask's first channel into red, green, blue and alpha, so the
    /// same image reads the same whether a filter downstream looks at luminance
    /// or at alpha. Internal rather than private: it is how a test builds a mask
    /// of its own without going through Vision.
    static func normalizedMask(_ mask: CIImage) -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = mask
        matrix.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        matrix.bVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        matrix.aVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        matrix.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        return matrix.outputImage ?? mask
    }
}
