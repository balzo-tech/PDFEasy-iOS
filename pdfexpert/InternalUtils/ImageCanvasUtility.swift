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

    /// One block of meme text, placed on the picture rather than above or below it.
    ///
    /// Everything is a **fraction of the image**, never a point size or a pixel
    /// offset. That is the whole trick behind the editor: the canvas on screen is
    /// a few hundred points tall and the export is a few thousand, and the same
    /// three numbers describe the same result at both sizes. A point size that
    /// looked right while dragging would come out invisible in the file.
    struct Caption: Identifiable, Equatable {

        let id: UUID
        var text: String
        /// Where the middle of the block sits, 0…1 across and down, origin at the
        /// top left — UIKit's orientation and SwiftUI's, so neither has to flip.
        var center: CGPoint
        /// Type height as a fraction of the image height.
        var scale: CGFloat

        init(id: UUID = UUID(), text: String = "", center: CGPoint, scale: CGFloat = 0.11) {
            self.id = id
            self.text = text
            self.center = center
            self.scale = scale
        }

        /// True when there is nothing to draw. Kept as a property rather than
        /// filtered away, because an empty block is still a thing the user is
        /// about to type into.
        var isBlank: Bool {
            self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// How the captions look. Shared by every block, because a meme with two
    /// different type treatments stops reading as a meme.
    struct CaptionStyle: Equatable {
        var fill: UIColor = .white
        var stroke: UIColor = .black
        /// Outline width, as a fraction of the type height.
        var strokeScale: CGFloat = 0.09
        var isUppercased: Bool = true
    }

    /// The share of the width a block may use before it wraps. The same number is
    /// used by the editor's live text, so a line that wraps on screen wraps in the
    /// file at the same word.
    static let captionWidthFraction: CGFloat = 0.92

    /// Where a block actually lands, measured rather than assumed.
    ///
    /// Two things depend on this and they must not disagree, so both ask here:
    /// the canvas, to place the live text, and the export, to draw it. The rect
    /// is the block's **own** size — as wide as the words need up to 92% of the
    /// picture, as tall as they wrap to — and never the full width. A block that
    /// always claimed 92% could not be dragged sideways at all: there was nowhere
    /// left to go.
    ///
    /// It is then clamped inside the picture. `Caption.center` is clamped too,
    /// but that only keeps the *middle* on the picture — three lines of type
    /// centred a tenth of the way down still start above the top edge, which is
    /// exactly how the first canvas cut "WHEN THE" off its own meme.
    static func captionFrame(_ caption: Caption,
                             style: CaptionStyle,
                             in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let text = style.isUppercased ? caption.text.uppercased(with: .current) : caption.text
        let font = Self.captionFont(forImageHeight: size.height, scale: caption.scale)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let limit = size.width * Self.captionWidthFraction
        // An empty block still needs a box, or there would be nothing to tap.
        let measured = NSAttributedString(string: text.isEmpty ? " " : text,
                                          attributes: [.font: font, .paragraphStyle: paragraph])
            .boundingRect(with: CGSize(width: limit, height: .greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                          context: nil)

        // A little slack on the width: the outline is drawn outside the glyphs,
        // and a box measured to the hair clips the last stroke.
        let width = min(ceil(measured.width) + font.pointSize * style.strokeScale * 2, limit)
        let height = ceil(measured.height)

        var origin = CGPoint(x: size.width * caption.center.x - width / 2,
                             y: size.height * caption.center.y - height / 2)
        origin.x = min(max(origin.x, 0), max(size.width - width, 0))
        origin.y = min(max(origin.y, 0), max(size.height - height, 0))
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    /// The font, at a size derived from the image. `.black` at a condensed width
    /// is as close as iOS gets to the face this format was born in; Impact is not
    /// on the system and shipping a font for one tool is not worth the binary.
    static func captionFont(forImageHeight height: CGFloat, scale: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: max(height * scale, 1), weight: .black)
            .withCondensedWidthIfAvailable()
    }

    /// Burns the captions into the picture at its own resolution.
    static func captioned(_ image: UIImage,
                          captions: [Caption],
                          style: CaptionStyle) -> UIImage {
        let lines = captions.filter { !$0.isBlank }
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
        let font = Self.captionFont(forImageHeight: size.height, scale: caption.scale)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        // Stroke and fill in one run, with a negative width: positive would draw
        // the outline *only*. The two-pass version this replaced drew the outline
        // under the fill, which doubled the glyph count for no visible gain.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: style.fill,
            .strokeColor: style.stroke,
            .strokeWidth: -(font.pointSize * style.strokeScale)
        ]

        // The very same rect the canvas placed the live text in.
        NSAttributedString(string: text, attributes: attributes)
            .draw(with: Self.captionFrame(caption, style: style, in: size),
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
