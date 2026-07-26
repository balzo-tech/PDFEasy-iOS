//
//  ScanImageProcessor.swift
//  PdfExpert
//
//  Turns a `ScannedPage` — a capture plus a crop, a filter and a rotation —
//  into pixels, through Core Image.
//
//  The order matters and is always the same: straighten first, then filter,
//  then turn. Filtering before straightening would measure contrast over the
//  table the page is lying on, and Otsu's threshold in particular would come out
//  of the wrong distribution.
//
//  Every entry point is synchronous and free of shared mutable state, so it can
//  be called from any queue; the callers decide what runs where.
//

import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ScanImageProcessor {

    /// One context for the whole app. Building a `CIContext` allocates a Metal
    /// command queue and its caches — doing it per page costs more than the
    /// filtering does.
    private static let context: CIContext = {
        CIContext(options: [.name: "scan", .cacheIntermediates: false])
    }()

    /// Renders a page as the user will see it.
    ///
    /// `maxDimension` caps the longest side: previews and thumbnails do not need
    /// twelve megapixels, and going through Core Image at full resolution for a
    /// 90-point thumbnail is what makes a scanner feel slow.
    static func render(_ page: ScannedPage, maxDimension: CGFloat? = nil) -> UIImage? {
        guard var image = self.ciImage(from: page.original) else { return nil }

        image = self.corrected(image, quad: page.quad)
        image = self.applying(page.filter, to: image)
        if let maxDimension {
            image = self.downscaled(image, maxDimension: maxDimension)
        }
        image = self.turned(image, by: page.rotation)

        guard let cgImage = self.context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// JPEG bytes for a rendered page — what goes into the PDF and into Photos.
    static func jpegData(for page: ScannedPage,
                         quality: CGFloat = K.Misc.ScanJpegQuality,
                         maxDimension: CGFloat? = nil) -> Data? {
        self.render(page, maxDimension: maxDimension)?.jpegData(compressionQuality: quality)
    }

    // MARK: - Steps

    /// Straightens the page out of the frame it was photographed in.
    ///
    /// `CIPerspectiveCorrection` both crops to the quad and undoes the
    /// perspective, so a page shot at an angle comes out rectangular rather than
    /// trapezoidal — the difference between a scan and a photo of a page.
    static func corrected(_ image: CIImage, quad: ScanQuad?) -> CIImage {
        guard let quad, quad.isUsable, !quad.isFullFrame else { return image }

        let points = quad.clamped().normalizedCorners().coreImagePoints(in: image.extent.size)
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = points.topLeft
        filter.topRight = points.topRight
        filter.bottomRight = points.bottomRight
        filter.bottomLeft = points.bottomLeft
        filter.crop = true

        guard let output = filter.outputImage,
              !output.extent.isEmpty,
              !output.extent.isInfinite,
              output.extent.width.isFinite,
              output.extent.height.isFinite else {
            return image
        }
        // Core Image leaves the result wherever the maths put it; move it back to
        // the origin so extents stay predictable down the chain.
        return output.transformed(by: CGAffineTransform(translationX: -output.extent.origin.x,
                                                        y: -output.extent.origin.y))
    }

    static func applying(_ filter: ScanFilter, to image: CIImage) -> CIImage {
        switch filter {
        case .original:
            return image

        case .document:
            let enhancer = CIFilter.documentEnhancer()
            enhancer.inputImage = image
            enhancer.amount = 1
            return enhancer.outputImage ?? image

        case .grayscale:
            let controls = CIFilter.colorControls()
            controls.inputImage = image
            controls.saturation = 0
            // A touch of contrast: stripping colour flattens a page that was
            // already low-contrast under room light.
            controls.contrast = 1.08
            return controls.outputImage ?? image

        case .blackAndWhite:
            // Otsu picks the threshold from this image's own histogram, so a
            // page shot in a dim room does not come out solid black the way a
            // fixed threshold would make it.
            let mono = CIFilter.colorControls()
            mono.inputImage = image
            mono.saturation = 0
            let threshold = CIFilter.colorThresholdOtsu()
            threshold.inputImage = mono.outputImage ?? image
            return threshold.outputImage ?? image
        }
    }

    static func turned(_ image: CIImage, by rotation: ScanRotation) -> CIImage {
        guard rotation != .none else { return image }
        // Clockwise on screen is a negative angle in Core Image's coordinate
        // space, whose y axis points up.
        let rotated = image.transformed(by: CGAffineTransform(rotationAngle: -rotation.radians))
        return rotated.transformed(by: CGAffineTransform(translationX: -rotated.extent.origin.x,
                                                         y: -rotated.extent.origin.y))
    }

    static func downscaled(_ image: CIImage, maxDimension: CGFloat) -> CIImage {
        let longestSide = max(image.extent.width, image.extent.height)
        guard longestSide > maxDimension, longestSide > 0 else { return image }
        let scale = maxDimension / longestSide
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    // MARK: - Bridging

    /// A `CIImage` with the capture's EXIF orientation already baked in.
    ///
    /// Without this every downstream coordinate — the detected quad, the crop
    /// handles, the corrected extent — would be in sensor space while the user
    /// is looking at the image upright, and each of them would be off by a
    /// quarter turn.
    static func ciImage(from image: UIImage) -> CIImage? {
        if let ciImage = image.ciImage {
            return ciImage.oriented(forExifOrientation: Int32(image.imageOrientation.exifValue))
        }
        guard let cgImage = image.cgImage else { return nil }
        return CIImage(cgImage: cgImage).oriented(forExifOrientation: Int32(image.imageOrientation.exifValue))
    }

    /// Renders a `CIImage` straight to a `UIImage`, for the callers that build
    /// their own chain (the live preview thumbnails).
    static func uiImage(from image: CIImage) -> UIImage? {
        guard let cgImage = self.context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}

extension UIImage.Orientation {

    /// The EXIF number Core Image wants for this orientation.
    var exifValue: Int {
        switch self {
        case .up: return 1
        case .upMirrored: return 2
        case .down: return 3
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .right: return 6
        case .rightMirrored: return 7
        case .left: return 8
        @unknown default: return 1
        }
    }
}
