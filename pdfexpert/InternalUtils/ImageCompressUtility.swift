//
//  ImageCompressUtility.swift
//  PdfExpert
//
//  "Compress images": make photographs smaller, several at a time.
//
//  The sibling of `PdfCompressUtility`, pointed at pictures instead of pages, and
//  built on the same principle: the compression is **run** rather than estimated,
//  because the only number anyone cares about — how much smaller it got — is the
//  one a real encode produces.
//
//  Everything here goes through ImageIO rather than `UIImage`. A modern phone
//  photograph is around 4000 px on its longest side, and `UIImage(data:)` decodes
//  all of it into memory before anything can be done with it: fifty of those at
//  once is more bitmap than this app is allowed to hold, which is the same reason
//  `HomeViewModel.loadImages` builds its pages one photo at a time.
//  `CGImageSourceCreateThumbnailAtIndex` decodes straight to the size we asked
//  for, so a 12 MP picture bound to 1600 px never exists at 12 MP.
//
//  Two consequences of re-encoding, both deliberate:
//
//  - **JPEG has no transparency.** A PNG cut-out would come back with a black
//    background, so anything carrying an alpha channel is composited onto white
//    first. The tool that makes those cut-outs is one tile away in the same
//    category, and handing one of them back ruined is not acceptable.
//  - **The metadata does not survive.** Camera model, timestamps and — the one
//    that matters — where the picture was taken are not copied into the output.
//    That is a feature worth saying out loud in the UI rather than a loss.
//

import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// How hard to squeeze what is left after the resize. The numbers match
/// `CompressionPreset`, its equivalent for documents: the same three words should
/// not mean two different things in two tools of the same app.
enum ImageCompressionQuality: Int32, CaseIterable, Identifiable {

    case light, balanced, maximum

    var id: Int32 { self.rawValue }

    var jpegQuality: CGFloat {
        switch self {
        case .light: return 0.8
        case .balanced: return 0.6
        case .maximum: return 0.4
        }
    }

    var title: String {
        switch self {
        case .light: return String(localized: "Light")
        case .balanced: return String(localized: "Balanced")
        case .maximum: return String(localized: "Maximum")
        }
    }

    var subtitle: String {
        switch self {
        case .light: return String(localized: "Barely visible quality loss")
        case .balanced: return String(localized: "Good quality, much smaller")
        case .maximum: return String(localized: "Smallest file, visible loss")
        }
    }

    var trackingParameterValue: String {
        switch self {
        case .light: return "light"
        case .balanced: return "balanced"
        case .maximum: return "maximum"
        }
    }
}

/// The longest side the picture is allowed to keep. Resolution is what actually
/// shrinks a photograph — quality alone barely dents a 12 MP file — so this is
/// the dial that does the work, and it is offered in the sizes pictures are
/// actually wanted at rather than in pixels people have to think about.
enum ImageCompressionSize: Int32, CaseIterable, Identifiable {

    case original, large, medium, small

    var id: Int32 { self.rawValue }

    /// nil leaves the picture at the size it arrived.
    var maxPixelSize: CGFloat? {
        switch self {
        case .original: return nil
        case .large: return 2560
        case .medium: return 1600
        case .small: return 1024
        }
    }

    var title: String {
        switch self {
        case .original: return String(localized: "Original")
        case .large: return String(localized: "Large")
        case .medium: return String(localized: "Medium")
        case .small: return String(localized: "Small")
        }
    }

    /// What the size is *for*, since "2560 px" tells most people nothing.
    var caption: String {
        switch self {
        case .original: return String(localized: "Same size")
        case .large: return String(localized: "Printing")
        case .medium: return String(localized: "Email")
        case .small: return String(localized: "Messaging")
        }
    }

    var trackingParameterValue: String {
        switch self {
        case .original: return "original"
        case .large: return "large"
        case .medium: return "medium"
        case .small: return "small"
        }
    }
}

struct ImageCompressionResult {

    let data: Data
    /// The size of the picture that comes out, in pixels. Shown next to the
    /// weight because a file half as heavy at half the width is a different
    /// bargain from one half as heavy at the same width.
    let pixelSize: CGSize
    let originalByteCount: Int

    var compressedByteCount: Int { self.data.count }

    /// 0…1, and zero when the result is not smaller — which happens with an
    /// already-compressed picture, and the UI has to be able to say so instead of
    /// showing a negative saving.
    var savedFraction: Double {
        guard self.originalByteCount > 0, self.isSmaller else { return 0 }
        return 1 - Double(self.compressedByteCount) / Double(self.originalByteCount)
    }

    var isSmaller: Bool { self.compressedByteCount < self.originalByteCount }
}

class ImageCompressUtility {

    /// Compresses the picture at `url`.
    ///
    /// Returns nil only when the file cannot be read as an image at all. A picture
    /// that simply cannot be shrunk comes back with `isSmaller == false`, so the
    /// caller can keep the original rather than save a heavier copy of it.
    static func compress(url: URL,
                         quality: ImageCompressionQuality,
                         size: ImageCompressionSize) -> ImageCompressionResult? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let byteCount = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return self.compress(source: source, originalByteCount: byteCount, quality: quality, size: size)
    }

    /// The same, for a picture that is already in memory — the camera hands one
    /// over that way, and so does every tool that passes its result along.
    static func compress(data: Data,
                         quality: ImageCompressionQuality,
                         size: ImageCompressionSize) -> ImageCompressionResult? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return self.compress(source: source, originalByteCount: data.count, quality: quality, size: size)
    }

    private static func compress(source: CGImageSource,
                                 originalByteCount: Int,
                                 quality: ImageCompressionQuality,
                                 size: ImageCompressionSize) -> ImageCompressionResult? {

        guard let pixelSize = self.pixelSize(of: source) else { return nil }

        // Never upscale. Asking for "large" on a picture that is already smaller
        // than large has to leave it alone, or the tool hands back a file that is
        // both heavier and no better.
        let longestSide = max(pixelSize.width, pixelSize.height)
        let bound = min(size.maxPixelSize ?? longestSide, longestSide)

        guard let decoded = self.decoded(source, boundedTo: bound) else { return nil }
        let flattened = self.flattenedOntoWhite(decoded)

        guard let data = self.jpegData(from: flattened, quality: quality.jpegQuality) else { return nil }
        return ImageCompressionResult(data: data,
                                      pixelSize: CGSize(width: flattened.width, height: flattened.height),
                                      originalByteCount: originalByteCount)
    }

    /// A small picture for a list row, decoded at list size rather than at camera
    /// size: the row shows a 120 pt square and has no use for twelve megapixels.
    static func thumbnail(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = self.decoded(source, boundedTo: maxPixelSize) else { return nil }
        return UIImage(cgImage: image)
    }

    /// The extension the bytes deserve — `jpg`, `png`, `heic`.
    ///
    /// A picked photograph arrives as bytes with no name on it, and the file it
    /// is parked in has to be named something. When the picture turns out not to
    /// be worth compressing it is that very file that gets shared, and a share
    /// sheet handed an `.img` nobody can identify offers the wrong apps or none.
    static func fileExtension(for data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier),
              let fileExtension = type.preferredFilenameExtension else {
            return "jpg"
        }
        return fileExtension
    }

    static func pixelSize(url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return self.pixelSize(of: source)
    }

    // MARK: - The pieces

    /// Reads the dimensions out of the header, without decoding a single pixel.
    private static func pixelSize(of source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0 else {
            return nil
        }
        // The header reports the stored dimensions; a portrait photo from a phone
        // is stored landscape with an orientation flag next to it. Swap them here,
        // because everything downstream — the bound, the readout, the aspect of
        // the thumbnail — is about the picture as it is seen.
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let isQuarterTurned = orientation >= 5 && orientation <= 8
        return isQuarterTurned ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    /// Decodes straight to the bound. `…FromImageAlways` because a file that
    /// happens to carry an embedded thumbnail would otherwise hand back that
    /// postage stamp instead of the picture, and `…WithTransform` because it is
    /// what applies the orientation flag — without it, every photo taken in
    /// portrait comes out on its side.
    private static func decoded(_ source: CGImageSource, boundedTo maxPixelSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize.rounded())
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// JPEG cannot carry an alpha channel, and an encoder handed one simply drops
    /// it — which turns everything transparent black. Anything with alpha is drawn
    /// onto white first; anything without is passed straight through, since the
    /// composite is a second full-size render nobody needs.
    private static func flattenedOntoWhite(_ image: CGImage) -> CGImage {
        guard self.hasAlpha(image) else { return image }
        let size = CGSize(width: image.width, height: image.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let flattened = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
        return flattened.cgImage ?? image
    }

    private static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }

    /// Encodes through ImageIO rather than `UIImage.jpegData`, because this is the
    /// destination that writes **only** what it is given: no EXIF, no camera make
    /// and model, and no GPS coordinates carried into a file that is usually being
    /// made smaller in order to send it to somebody.
    private static func jpegData(from image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data,
                                                                 UTType.jpeg.identifier as CFString,
                                                                 1,
                                                                 nil) else {
            return nil
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
