//
//  ImageCanvasUtility.swift
//  PdfExpert
//
//  The engine behind the two tools that work on a picture and give back a
//  picture — the image editor and the meme maker.
//
//  Everything here is a recipe on a `CIImage` rather than a rendered bitmap, for
//  the reason `BackgroundRemovalViewModel` explains at length: Core Image is
//  lazy, so the preview and the export are the same chain evaluated at two
//  sizes. The one exception is the caption, which is drawn with UIKit because
//  text is not a filter — and it takes the size it is drawn into as an argument
//  so that what the preview shows is what the export writes.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ImageCanvasUtility {

    // MARK: - Geometry

    /// Mirrors the image left-to-right.
    ///
    /// `CGAffineTransform(scaleX: -1, y: 1)` moves the extent into negative x, so
    /// it is put back where it was: a Core Image extent with a negative origin
    /// renders as empty space in every consumer downstream.
    static func mirrored(_ image: CIImage) -> CIImage {
        let extent = image.extent
        return image
            .transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            .transformed(by: CGAffineTransform(translationX: extent.maxX + extent.minX, y: 0))
    }

    /// Centre-crops to an aspect ratio, taking the largest rectangle that fits.
    ///
    /// `nil` keeps the picture as it is. The crop is centred because these are
    /// social formats — a square for a grid, a tall frame for a story — and the
    /// subject of a photograph is near the middle far more often than not.
    static func cropped(_ image: CIImage, toAspect aspect: CGFloat?) -> CIImage {
        guard let aspect, aspect > 0 else { return image }
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }

        let current = extent.width / extent.height
        var size = extent.size
        if current > aspect {
            size.width = extent.height * aspect
        } else {
            size.height = extent.width / aspect
        }
        let origin = CGPoint(x: extent.midX - size.width / 2, y: extent.midY - size.height / 2)
        // Back to the origin: a cropped image keeps the coordinates it was cut
        // from, and every later step here assumes a rect that starts at zero.
        return image
            .cropped(to: CGRect(origin: origin, size: size))
            .transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
    }

    // MARK: - Colour

    /// The three dials the editor offers, in one pass.
    ///
    /// All three are no-ops at zero, so an untouched photograph comes out of the
    /// chain bit-identical to the one that went in — the filter is skipped
    /// entirely rather than applied with neutral values, which would still cost
    /// a colour-space round trip on a 12-megapixel image.
    static func adjusted(_ image: CIImage,
                         brightness: Float,
                         contrast: Float,
                         saturation: Float) -> CIImage {
        guard brightness != 0 || contrast != 0 || saturation != 0 else { return image }
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = brightness
        // Core Image counts contrast and saturation from 1, the dials from 0.
        filter.contrast = 1 + contrast
        filter.saturation = 1 + saturation
        return filter.outputImage ?? image
    }

    // MARK: - Captions

    /// Where a line of caption sits.
    enum CaptionPosition {
        case top
        case bottom
    }

    /// One line of meme text, and how it should look.
    struct Caption {
        var text: String
        var position: CaptionPosition
    }

    /// How the captions are drawn — shared by both lines, because a meme with two
    /// different type treatments stops reading as a meme.
    struct CaptionStyle {
        /// Height of the type as a fraction of the *image* height, not a point
        /// size. A point size that looks right on a preview is invisible on a
        /// 4032-pixel photograph, and this is the whole reason the preview and
        /// the export agree.
        var scale: CGFloat = 0.11
        var fill: UIColor = .white
        var stroke: UIColor = .black
        /// Outline width, as a fraction of the type height.
        var strokeScale: CGFloat = 0.09
        var isUppercased: Bool = true
    }

    /// Draws the captions onto the image at whatever size it is.
    ///
    /// Called twice for the same state: once on the downscaled preview while the
    /// user types, once on the full-resolution original on the way out.
    static func captioned(_ image: UIImage,
                          captions: [Caption],
                          style: CaptionStyle) -> UIImage {
        let lines = captions.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !lines.isEmpty else { return image }

        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        // The image is already in pixels at the size we want; letting the
        // renderer apply the screen scale on top would triple the export.
        format.scale = image.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            for caption in lines {
                Self.draw(caption, style: style, in: size)
            }
        }
    }

    private static func draw(_ caption: Caption, style: CaptionStyle, in size: CGSize) {
        let text = style.isUppercased ? caption.text.uppercased(with: .current) : caption.text
        let pointSize = size.height * style.scale
        // `.black` at a condensed width is as close as iOS gets to the face this
        // format was born in; Impact is not on the system and shipping a font
        // for one tool is not worth the binary.
        let font = UIFont.systemFont(ofSize: pointSize, weight: .black).withCondensedWidthIfAvailable()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let inset = size.width * 0.04
        let available = CGSize(width: size.width - inset * 2, height: size.height * 0.45)

        // Stroke first, fill second, as two passes: `.strokeWidth` negative in a
        // single attributed run draws both, but thins the outline where glyphs
        // overlap, which is exactly where this format needs it thickest.
        let outlined: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: style.fill,
            .strokeColor: style.stroke,
            .strokeWidth: -(pointSize * style.strokeScale)
        ]

        let attributed = NSAttributedString(string: text, attributes: outlined)
        let bounds = attributed.boundingRect(with: available,
                                             options: [.usesLineFragmentOrigin, .usesFontLeading],
                                             context: nil)

        let y: CGFloat
        switch caption.position {
        case .top:
            y = inset
        case .bottom:
            y = size.height - bounds.height - inset
        }
        attributed.draw(with: CGRect(x: inset, y: y, width: available.width, height: bounds.height),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil)
    }
}

private extension UIFont {

    /// The condensed cut where the system has one, the plain weight where it
    /// does not. Meme captions are long and the frame is fixed: narrower glyphs
    /// buy a couple of words before the line wraps.
    func withCondensedWidthIfAvailable() -> UIFont {
        guard #available(iOS 16.0, *) else { return self }
        let descriptor = self.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.width: UIFont.Width.condensed.rawValue]
        ])
        return UIFont(descriptor: descriptor, size: self.pointSize)
    }
}
