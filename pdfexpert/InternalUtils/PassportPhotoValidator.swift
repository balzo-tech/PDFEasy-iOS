//
//  PassportPhotoValidator.swift
//  PdfExpert
//
//  Whether the photo would survive the counter.
//
//  This is the part that is worth paying for. Cropping to 35 × 45 mm is
//  arithmetic; telling somebody *before* they print six copies that the lamp
//  behind them threw a shadow on the wall, or that their head is tilted eight
//  degrees, is the whole product. It is also where the competition earns its
//  worst reviews — an app that says "approved" and an office that says no is
//  worse than an app that says nothing.
//
//  So the checks here are built to be *believed*, which means two rules:
//
//  1. **A failure has to be something we can actually see.** A tilted head, a
//     head that runs off the top of the frame, a closed eye — measured, not
//     inferred. Everything softer is a warning.
//  2. **Every failure carries the fix**, and where the fix is a control on this
//     screen the advice names it. "Not enough room above your head" is a dead
//     end; "…or switch to a plain backdrop and the app will fill it in" is not.
//
//  The thresholds are tuned by eye on real photographs and gathered at the top
//  of the file rather than scattered through it, because they will need moving
//  and moving them is the maintenance this feature has.
//

import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct PassportPhotoCheck: Identifiable, Hashable {

    enum Outcome: Int, Comparable, Hashable {
        case pass
        case warning
        case failure

        static func < (lhs: Outcome, rhs: Outcome) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum Kind: String, Hashable {
        case framing
        case headSize
        case pose
        case eyes
        case expression
        case sharpness
        case lighting
        case evenLighting
        case background
        case resolution
    }

    let id: Kind
    let outcome: Outcome
    /// Phrased as the finding, not as the test: "Head is tilted", not "Pose".
    let title: String
    /// What to do about it. `nil` when it passed — there is nothing to do.
    let advice: String?

    var systemImage: String {
        switch self.outcome {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.circle.fill"
        }
    }
}

enum PassportPhotoValidator {

    // MARK: - Thresholds
    //
    // Degrees, ratios and luminances, all measured on the photograph rather than
    // on the finished crop. Every one of them is a judgement call; what is not a
    // judgement call is that a `failure` must be visible to the user when they
    // look at their own photo, or the checklist stops being believed.

    /// Head rotation. ICAO asks for "full face, square to the camera"; nobody
    /// holds still to a degree, and rejecting five degrees of tilt would reject
    /// most passable photographs.
    private static let poseWarningDegrees: CGFloat = 5
    private static let poseFailureDegrees: CGFloat = 11
    /// Pitch — nodding — is the least reliable of the three and never fails on
    /// its own.
    private static let pitchWarningDegrees: CGFloat = 12

    /// Eyelid opening over eye width. An open eye measures around 0.30, a squint
    /// 0.20, a shut eye 0.10. Only the last of those is called a failure.
    private static let eyeFailureRatio: CGFloat = 0.13
    private static let eyeWarningRatio: CGFloat = 0.20

    /// Inner-lip opening over mouth width. Never a failure: a closed-mouth smile
    /// is accepted nearly everywhere, and an app that refuses one is an app
    /// people stop trusting.
    private static let mouthWarningRatio: CGFloat = 0.16

    /// Mean absolute high-pass over the face. A sharp face lands around 0.03, a
    /// soft one 0.01, an unusable one under 0.005.
    private static let sharpnessFailure: CGFloat = 0.004
    private static let sharpnessWarning: CGFloat = 0.011

    /// Mean luminance of the face.
    private static let faceTooDark: CGFloat = 0.26
    private static let faceTooBright: CGFloat = 0.88
    /// Left half against right half, as a share of the brighter one. Side
    /// lighting is the most common reason a photo comes back.
    private static let sideLightWarning: CGFloat = 0.18
    private static let sideLightFailure: CGFloat = 0.34

    /// Spread between the brightest and darkest corner of the frame, when the
    /// original background is kept.
    private static let backgroundSpreadWarning: CGFloat = 0.10
    private static let backgroundSpreadFailure: CGFloat = 0.20
    private static let backgroundTooDark: CGFloat = 0.55

    /// How much upscaling is tolerable before the print goes soft.
    private static let resolutionWarningShare: CGFloat = 1.0
    private static let resolutionFailureShare: CGFloat = 0.6

    // MARK: - Running the checks

    /// Everything the checklist shows, worst first.
    ///
    /// `image` is the working copy — a downscale of the photograph — and
    /// `imageScale` maps the full-resolution rectangles in `geometry` and `crop`
    /// onto it. Measuring at preview resolution is deliberate: shadows and
    /// backgrounds are low-frequency, none of these numbers moves when the pixels
    /// get smaller, and doing it at twelve megapixels would put a second of work
    /// behind every tap on a swatch.
    static func checks(for spec: PassportPhotoSpec,
                       geometry: PassportFaceGeometry,
                       crop: CGRect,
                       background: PassportBackground,
                       image: CIImage,
                       imageScale: CGFloat) -> [PassportPhotoCheck] {

        var checks: [PassportPhotoCheck] = []
        checks.append(self.framingCheck(geometry: geometry, crop: crop, background: background))
        checks.append(self.headSizeCheck(spec: spec, geometry: geometry, background: background))
        checks.append(self.poseCheck(geometry: geometry))
        if let eyes = self.eyesCheck(geometry: geometry) { checks.append(eyes) }
        if let mouth = self.expressionCheck(geometry: geometry) { checks.append(mouth) }
        checks.append(self.resolutionCheck(spec: spec, crop: crop))

        let faceRect = geometry.faceRect.applying(CGAffineTransform(scaleX: imageScale, y: imageScale))
        if let sharpness = self.sharpnessCheck(image: image, faceRect: faceRect) { checks.append(sharpness) }
        checks.append(contentsOf: self.lightingChecks(image: image, faceRect: faceRect))
        checks.append(self.backgroundCheck(image: image,
                                           crop: crop.applying(CGAffineTransform(scaleX: imageScale, y: imageScale)),
                                           background: background))

        // Worst first, and stable within a severity so the list does not
        // reshuffle itself while the user is reading it.
        return checks.enumerated()
            .sorted { left, right in
                guard left.element.outcome == right.element.outcome else {
                    return left.element.outcome > right.element.outcome
                }
                return left.offset < right.offset
            }
            .map(\.element)
    }

    static func worstOutcome(in checks: [PassportPhotoCheck]) -> PassportPhotoCheck.Outcome {
        checks.map(\.outcome).max() ?? .pass
    }

    // MARK: - Geometry

    /// Does the frame the country asks for actually fit around this head?
    ///
    /// The answer depends on the backdrop, which is the useful part. With the
    /// background being replaced, anything the crop reaches beyond the edge of
    /// the photograph is painted in, so only the *head itself* has to be inside.
    /// Keeping the original background, every pixel has to exist.
    private static func framingCheck(geometry: PassportFaceGeometry,
                                     crop: CGRect,
                                     background: PassportBackground) -> PassportPhotoCheck {
        let extent = geometry.imageExtent
        // A head touching the very edge of the sensor is a head that was cut off
        // before the shutter fired, whatever the detector says it found.
        let margin = min(extent.width, extent.height) * 0.005
        if geometry.crownY > extent.maxY - margin {
            return PassportPhotoCheck(
                id: .framing, outcome: .failure,
                title: String(localized: "The top of the head is cut off"),
                advice: String(localized: "Take the photo again with some space above the hair."))
        }
        if geometry.chinY < extent.minY + margin {
            return PassportPhotoCheck(
                id: .framing, outcome: .failure,
                title: String(localized: "The chin is cut off"),
                advice: String(localized: "Take the photo again with the whole head and the top of the shoulders in frame."))
        }

        if background.replacesBackground {
            return PassportPhotoCheck(
                id: .framing, outcome: .pass,
                title: String(localized: "The head fits the frame"),
                advice: nil)
        }

        if !extent.contains(crop) {
            return PassportPhotoCheck(
                id: .framing, outcome: .failure,
                title: String(localized: "Not enough room around the head"),
                advice: String(localized: "Choose a plain background above and the app fills in what is missing — or move further from the camera and take it again."))
        }
        return PassportPhotoCheck(
            id: .framing, outcome: .pass,
            title: String(localized: "The frame fits inside the photo"),
            advice: nil)
    }

    /// The head is cropped to the right height by construction, so what is
    /// reported here is how much that number can be trusted.
    private static func headSizeCheck(spec: PassportPhotoSpec,
                                      geometry: PassportFaceGeometry,
                                      background: PassportBackground) -> PassportPhotoCheck {
        let millimetres = spec.targetFaceHeight
        let formatted = String(format: "%.0f", Double(millimetres))
        guard geometry.crownWasMeasured else {
            return PassportPhotoCheck(
                id: .headSize, outcome: .warning,
                title: String(localized: "Head height is estimated, not measured"),
                advice: String(localized: "Choose a plain background and the app measures the top of the hair instead of guessing it."))
        }
        return PassportPhotoCheck(
            id: .headSize, outcome: .pass,
            title: String(localized: "Head measures \(formatted) mm, chin to crown"),
            advice: nil)
    }

    private static func poseCheck(geometry: PassportFaceGeometry) -> PassportPhotoCheck {
        let roll = abs(geometry.rollDegrees)
        let yaw = abs(geometry.yawDegrees)
        let pitch = abs(geometry.pitchDegrees)

        if roll >= self.poseFailureDegrees {
            return PassportPhotoCheck(
                id: .pose, outcome: .failure,
                title: String(localized: "The head is tilted to one side"),
                advice: String(localized: "Hold the camera level and keep your head straight."))
        }
        if yaw >= self.poseFailureDegrees {
            return PassportPhotoCheck(
                id: .pose, outcome: .failure,
                title: String(localized: "The head is turned away from the camera"),
                advice: String(localized: "Look straight into the lens, with both ears equally visible."))
        }
        if roll >= self.poseWarningDegrees || yaw >= self.poseWarningDegrees {
            return PassportPhotoCheck(
                id: .pose, outcome: .warning,
                title: String(localized: "The head is slightly off square"),
                advice: String(localized: "Look straight into the lens, with your head upright."))
        }
        if pitch >= self.pitchWarningDegrees {
            return PassportPhotoCheck(
                id: .pose, outcome: .warning,
                title: String(localized: "The chin is raised or lowered"),
                advice: String(localized: "Hold the camera at eye level."))
        }
        return PassportPhotoCheck(
            id: .pose, outcome: .pass,
            title: String(localized: "Facing the camera straight on"),
            advice: nil)
    }

    private static func eyesCheck(geometry: PassportFaceGeometry) -> PassportPhotoCheck? {
        guard let openness = geometry.eyeOpenness else { return nil }
        if openness < self.eyeFailureRatio {
            return PassportPhotoCheck(
                id: .eyes, outcome: .failure,
                title: String(localized: "The eyes look closed"),
                advice: String(localized: "Both eyes have to be open and visible."))
        }
        if openness < self.eyeWarningRatio {
            return PassportPhotoCheck(
                id: .eyes, outcome: .warning,
                title: String(localized: "The eyes look half shut"),
                advice: String(localized: "Open your eyes wide and avoid squinting into the light."))
        }
        return PassportPhotoCheck(
            id: .eyes, outcome: .pass,
            title: String(localized: "Eyes open and visible"),
            advice: nil)
    }

    private static func expressionCheck(geometry: PassportFaceGeometry) -> PassportPhotoCheck? {
        guard let openness = geometry.mouthOpenness else { return nil }
        guard openness >= self.mouthWarningRatio else {
            return PassportPhotoCheck(
                id: .expression, outcome: .pass,
                title: String(localized: "Neutral expression, mouth closed"),
                advice: nil)
        }
        return PassportPhotoCheck(
            id: .expression, outcome: .warning,
            title: String(localized: "The mouth is open"),
            advice: String(localized: "Keep a neutral expression with your mouth closed."))
    }

    /// Whether the source has enough pixels for the print, or whether the crop
    /// is being blown up.
    private static func resolutionCheck(spec: PassportPhotoSpec, crop: CGRect) -> PassportPhotoCheck {
        let required = spec.pixelSize(dpi: spec.minimumDPI)
        let share = crop.height / max(required.height, 1)
        let dpi = spec.minimumDPI

        if share < self.resolutionFailureShare {
            return PassportPhotoCheck(
                id: .resolution, outcome: .failure,
                title: String(localized: "Not enough detail for a \(dpi) dpi print"),
                advice: String(localized: "Use a photo taken with the main camera, closer to the subject."))
        }
        if share < self.resolutionWarningShare {
            return PassportPhotoCheck(
                id: .resolution, outcome: .warning,
                title: String(localized: "The print will be slightly enlarged"),
                advice: String(localized: "It will look fine on paper, but a closer photo would be sharper."))
        }
        return PassportPhotoCheck(
            id: .resolution, outcome: .pass,
            title: String(localized: "Sharp enough for \(dpi) dpi"),
            advice: nil)
    }

    // MARK: - Pixels

    /// Sharpness as the mean absolute difference between the face and a blurred
    /// copy of it.
    ///
    /// A variance-of-Laplacian would be the textbook answer and needs a
    /// floating-point render to keep its negative values; the difference blend
    /// gives the absolute value for free and ranks photographs in the same
    /// order, which is all a threshold needs.
    private static func sharpnessCheck(image: CIImage, faceRect: CGRect) -> PassportPhotoCheck? {
        let region = faceRect.intersection(image.extent)
        guard !region.isNull, region.width >= 8, region.height >= 8 else { return nil }

        let mono = CIFilter.colorControls()
        mono.inputImage = image
        mono.saturation = 0
        guard let grey = mono.outputImage else { return nil }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = grey.clampedToExtent()
        blur.radius = Float(max(min(region.width, region.height) * 0.01, 1))
        guard let blurred = blur.outputImage?.cropped(to: image.extent) else { return nil }

        let difference = CIFilter.differenceBlendMode()
        difference.inputImage = grey
        difference.backgroundImage = blurred
        guard let detail = difference.outputImage,
              let average = PassportPhotoUtility.averageColour(of: detail, in: region) else { return nil }
        let sharpness = self.luminance(average)

        if sharpness < self.sharpnessFailure {
            return PassportPhotoCheck(
                id: .sharpness, outcome: .failure,
                title: String(localized: "The photo is out of focus"),
                advice: String(localized: "Take it again, holding the camera still and tapping the face to focus."))
        }
        if sharpness < self.sharpnessWarning {
            return PassportPhotoCheck(
                id: .sharpness, outcome: .warning,
                title: String(localized: "The face looks soft"),
                advice: String(localized: "Tap the face to focus before taking the photo."))
        }
        return PassportPhotoCheck(
            id: .sharpness, outcome: .pass,
            title: String(localized: "The face is in focus"),
            advice: nil)
    }

    /// Exposure, and then the one that actually gets photos rejected: a lamp on
    /// one side and a shadow on the other.
    private static func lightingChecks(image: CIImage, faceRect: CGRect) -> [PassportPhotoCheck] {
        let region = faceRect.intersection(image.extent)
        guard !region.isNull, region.width >= 8, region.height >= 8,
              let average = PassportPhotoUtility.averageColour(of: image, in: region) else { return [] }

        var checks: [PassportPhotoCheck] = []
        let brightness = self.luminance(average)
        if brightness < self.faceTooDark {
            checks.append(PassportPhotoCheck(
                id: .lighting, outcome: .warning,
                title: String(localized: "The face is underexposed"),
                advice: String(localized: "Face a window or a lamp, so the light falls on you rather than behind you.")))
        } else if brightness > self.faceTooBright {
            checks.append(PassportPhotoCheck(
                id: .lighting, outcome: .warning,
                title: String(localized: "The face is washed out"),
                advice: String(localized: "Move out of direct sunlight or turn the flash off.")))
        } else {
            checks.append(PassportPhotoCheck(
                id: .lighting, outcome: .pass,
                title: String(localized: "Evenly exposed"),
                advice: nil))
        }

        // Halves of the face, not of the frame: the frame includes the backdrop,
        // and a bright wall on one side would report a shadow that is not on
        // anybody's face.
        let left = CGRect(x: region.minX, y: region.minY, width: region.width / 2, height: region.height)
        let right = CGRect(x: region.midX, y: region.minY, width: region.width / 2, height: region.height)
        guard let leftAverage = PassportPhotoUtility.averageColour(of: image, in: left),
              let rightAverage = PassportPhotoUtility.averageColour(of: image, in: right) else { return checks }
        let leftLuminance = self.luminance(leftAverage)
        let rightLuminance = self.luminance(rightAverage)
        let brighter = max(leftLuminance, rightLuminance)
        guard brighter > 0.01 else { return checks }
        let difference = abs(leftLuminance - rightLuminance) / brighter

        if difference >= self.sideLightFailure {
            checks.append(PassportPhotoCheck(
                id: .evenLighting, outcome: .failure,
                title: String(localized: "One side of the face is in shadow"),
                advice: String(localized: "Turn to face the light, or stand where it reaches both sides of your face.")))
        } else if difference >= self.sideLightWarning {
            checks.append(PassportPhotoCheck(
                id: .evenLighting, outcome: .warning,
                title: String(localized: "The light is uneven across the face"),
                advice: String(localized: "Turn towards the light so both sides are lit the same.")))
        } else {
            checks.append(PassportPhotoCheck(
                id: .evenLighting, outcome: .pass,
                title: String(localized: "The face is lit evenly"),
                advice: nil))
        }
        return checks
    }

    /// The backdrop. With one painted in there is nothing to measure and the
    /// line says so plainly; with the original kept, the four corners of the
    /// frame have to agree with each other.
    private static func backgroundCheck(image: CIImage,
                                        crop: CGRect,
                                        background: PassportBackground) -> PassportPhotoCheck {
        guard !background.replacesBackground else {
            return PassportPhotoCheck(
                id: .background, outcome: .pass,
                title: String(localized: "Plain, even background"),
                advice: nil)
        }

        // Where the wall is, and nowhere else. The obvious four corners would be
        // wrong: the bottom two hold shoulders in every portrait ever taken, so
        // a dark jumper against a light wall would be reported as a patterned
        // background — a failure the user cannot act on, on a photograph that is
        // fine. These four are the top corners and the two strips beside the
        // head at eye level, all of which are wall in any photo framed the way
        // this tool has just framed it.
        let patchWidth = crop.width * 0.12
        let patchHeight = crop.height * 0.10
        let eyeLevel = crop.maxY - crop.height * 0.42 - patchHeight
        let samples = [
            CGRect(x: crop.minX, y: crop.maxY - patchHeight, width: patchWidth, height: patchHeight),
            CGRect(x: crop.maxX - patchWidth, y: crop.maxY - patchHeight, width: patchWidth, height: patchHeight),
            CGRect(x: crop.minX, y: eyeLevel, width: patchWidth, height: patchHeight),
            CGRect(x: crop.maxX - patchWidth, y: eyeLevel, width: patchWidth, height: patchHeight),
        ]
        // A sample that falls outside the photograph is a sample that is
        // missing, not one that failed.
        let luminances = samples
            .compactMap { PassportPhotoUtility.averageColour(of: image, in: $0) }
            .map(self.luminance)
        guard luminances.count >= 2, let low = luminances.min(), let high = luminances.max() else {
            return PassportPhotoCheck(
                id: .background, outcome: .warning,
                title: String(localized: "The background could not be checked"),
                advice: String(localized: "Choose a plain background above to be sure of it."))
        }

        let spread = high - low
        if spread >= self.backgroundSpreadFailure {
            return PassportPhotoCheck(
                id: .background, outcome: .failure,
                title: String(localized: "The background is not uniform"),
                advice: String(localized: "Choose a plain background above and the app replaces it."))
        }
        if spread >= self.backgroundSpreadWarning {
            return PassportPhotoCheck(
                id: .background, outcome: .warning,
                title: String(localized: "The background is slightly uneven"),
                advice: String(localized: "Choose a plain background above and the app replaces it."))
        }
        if high < self.backgroundTooDark {
            return PassportPhotoCheck(
                id: .background, outcome: .warning,
                title: String(localized: "The background is too dark"),
                advice: String(localized: "Identity photos need a light background — choose one above."))
        }
        return PassportPhotoCheck(
            id: .background, outcome: .pass,
            title: String(localized: "The background is plain and light"),
            advice: nil)
    }

    /// Rec. 709 luminance, which is what the eye means by "how bright is this".
    private static func luminance(_ colour: (red: CGFloat, green: CGFloat, blue: CGFloat)) -> CGFloat {
        0.2126 * colour.red + 0.7152 * colour.green + 0.0722 * colour.blue
    }
}
