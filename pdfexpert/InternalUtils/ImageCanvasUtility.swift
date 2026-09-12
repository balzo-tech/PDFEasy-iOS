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
        ///
        /// Only `x` is ignored when the block is anchored to an edge: see
        /// `CaptionAlignment`.
        var center: CGPoint
        /// Type height as a fraction of the image height.
        var scale: CGFloat
        /// How the words sit across the picture. Per block, not per meme: the
        /// caption at the top can hug the left while the one at the bottom is
        /// centred.
        var alignment: CaptionAlignment

        init(id: UUID = UUID(),
             text: String = "",
             center: CGPoint,
             scale: CGFloat = 0.11,
             alignment: CaptionAlignment = .center) {
            self.id = id
            self.text = text
            self.center = center
            self.scale = scale
            self.alignment = alignment
        }

        /// True when there is nothing to draw. Kept as a property rather than
        /// filtered away, because an empty block is still a thing the user is
        /// about to type into.
        var isBlank: Bool {
            self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Where a block sits across the picture, and how its own lines line up.
    ///
    /// One control doing two jobs, on purpose. Asking a person to set the
    /// paragraph alignment *and* then drag the block to the matching edge is two
    /// chores for one intention: "put these words on the left". So `leading`
    /// pins the box against the left margin **and** ranges its lines left, and
    /// `trailing` does the mirror. `center` is the meme format's own and leaves
    /// the block wherever it was dragged.
    ///
    /// The anchored cases override `Caption.center.x` — which is why dragging an
    /// anchored block hands it back to `center` first (`unanchor`), keeping it
    /// exactly where it appears rather than letting it jump.
    enum CaptionAlignment: String, CaseIterable, Identifiable, Equatable {

        case leading
        case center
        case trailing

        var id: String { self.rawValue }

        /// Left and right rather than natural: a meme is a picture, and the
        /// words go where the user points, not where the script direction wants
        /// them.
        var textAlignment: NSTextAlignment {
            switch self {
            case .leading: return .left
            case .center: return .center
            case .trailing: return .right
            }
        }

        /// Spoken, not shown: the control is three glyphs.
        var title: String {
            switch self {
            case .leading: return String(localized: "Align left")
            case .center: return String(localized: "Align centre")
            case .trailing: return String(localized: "Align right")
            }
        }

        var symbolName: String {
            switch self {
            case .leading: return "text.alignleft"
            case .center: return "text.aligncenter"
            case .trailing: return "text.alignright"
            }
        }
    }

    /// The faces the meme maker offers.
    ///
    /// Impact leads, and an earlier note here was simply wrong about it: it said
    /// "Impact is not on the system and shipping a font for one tool is not worth
    /// the binary", and settled for the system black condensed. Impact ships with
    /// iOS — `UIFont.fontNames(forFamilyName: "Impact")` answers on a stock
    /// device — and it is the face this format was born in. Nothing else looks
    /// right at the top of a picture.
    ///
    /// Every case falls back to a system face rather than to `nil`: a font that
    /// is missing must still draw something, or the export comes back blank on
    /// the one device that does not have it.
    enum CaptionFace: String, CaseIterable, Identifiable, Equatable {

        /// The meme face.
        case impact
        /// The system's own black condensed — what this tool drew before Impact,
        /// and still the cleanest option on a busy photograph.
        case sans
        case rounded
        /// Hand-lettered, for the captions that are meant to read as an aside.
        case marker
        case serif

        var id: String { self.rawValue }

        /// Shown on the chip, and drawn *in the face itself* — a list of five
        /// names in one font tells the user nothing about what they are picking.
        var title: String {
            switch self {
            // Not localized: Impact is the name of a typeface, not a word.
            case .impact: return "Impact"
            case .sans: return String(localized: "Sans")
            case .rounded: return String(localized: "Rounded")
            case .marker: return String(localized: "Marker")
            case .serif: return String(localized: "Serif")
            }
        }

        func font(ofSize size: CGFloat) -> UIFont {
            let size = max(size, 1)
            switch self {
            case .impact:
                return UIFont(name: "Impact", size: size) ?? Self.systemCondensed(size)
            case .sans:
                return Self.systemCondensed(size)
            case .rounded:
                return Self.system(size, design: .rounded)
            case .marker:
                return UIFont(name: "MarkerFelt-Wide", size: size) ?? Self.systemCondensed(size)
            case .serif:
                return UIFont(name: "Georgia-Bold", size: size) ?? Self.system(size, design: .serif)
            }
        }

        private static func systemCondensed(_ size: CGFloat) -> UIFont {
            UIFont.systemFont(ofSize: size, weight: .black).withCondensedWidthIfAvailable()
        }

        /// The system face in one of its designs. A descriptor that the device
        /// cannot satisfy gives back the plain black weight, which is the same
        /// answer `systemFont` would have given anyway.
        private static func system(_ size: CGFloat, design: UIFontDescriptor.SystemDesign) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: .black)
            guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
            return UIFont(descriptor: descriptor, size: size)
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
        var face: CaptionFace = .impact
    }

    /// The outline for a fill: black under a light colour, white under a dark
    /// one.
    ///
    /// It used to be a property on the three presets — white and yellow took
    /// black, black took white — which stopped working the moment the panel
    /// grew a colour wheel and a caption could be any colour at all. So it is
    /// measured instead: the outline exists because half the photographs in the
    /// world are the same tone as the words on them, and it only does its job
    /// while it is the opposite of the fill.
    ///
    /// Perceived brightness, not the plain average: the eye reads green as far
    /// brighter than blue at the same number, and an average would put a white
    /// outline under a green caption where it is worth nothing.
    static func outline(for fill: UIColor) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        var white: CGFloat = 0
        let brightness: CGFloat
        if fill.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            brightness = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        } else if fill.getWhite(&white, alpha: &alpha) {
            brightness = white
        } else {
            // Nothing readable came back — a pattern colour, say. Black is the
            // outline the format was born with.
            return .black
        }
        return brightness > 0.5 ? .black : .white
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
        let font = Self.captionFont(forImageHeight: size.height,
                                    scale: caption.scale,
                                    face: style.face)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = caption.alignment.textAlignment
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

        // An anchored block ignores `center.x` and takes the margin instead —
        // the same margin the wrapping width leaves, so the words line up with
        // the edge of the widest line a centred block could ever have.
        let inset = size.width * (1 - Self.captionWidthFraction) / 2
        let x: CGFloat
        switch caption.alignment {
        case .leading: x = inset
        case .center: x = size.width * caption.center.x - width / 2
        case .trailing: x = size.width - inset - width
        }
        var origin = CGPoint(x: x, y: size.height * caption.center.y - height / 2)
        origin.x = min(max(origin.x, 0), max(size.width - width, 0))
        origin.y = min(max(origin.y, 0), max(size.height - height, 0))
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    /// The chosen face, at a size derived from the image. The size is a fraction
    /// of the picture and never a point value, for the reason `Caption` gives:
    /// the canvas is a few hundred points tall and the export a few thousand.
    static func captionFont(forImageHeight height: CGFloat,
                            scale: CGFloat,
                            face: CaptionFace) -> UIFont {
        face.font(ofSize: height * scale)
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
        let font = Self.captionFont(forImageHeight: size.height,
                                    scale: caption.scale,
                                    face: style.face)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = caption.alignment.textAlignment
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
