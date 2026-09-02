//
//  PassportPhotoUtility.swift
//  PdfExpert
//
//  Turning a photograph into an identity photo: find the head, work out where
//  the crown and the chin are, and cut a frame around them that satisfies a
//  country's rules.
//
//  Two measurements decide everything, and only one of them is easy. The chin
//  comes straight from Vision's face contour. The **crown does not**: Vision's
//  face rectangle stops around the eyebrows, and every country measures to the
//  top of the head *including the hair* — which is exactly what a face detector
//  is trained to ignore. Estimating it from the face box is where competing apps
//  get the head height wrong, and a head 4 mm too short is a refused photo.
//
//  So the crown is read from the subject silhouette that
//  `BackgroundRemovalUtility` already produces: the topmost covered row in a
//  band above the face is the top of the hair, measured rather than assumed.
//  That is the reason the two tools share an engine, and the reason this one is
//  worth selling. When there is no mask — the user kept their own background —
//  the anthropometric fallback takes over and says so, and the checklist reports
//  the head height as estimated rather than measured.
//
//  Everything below works in Core Image's coordinate space: pixels, origin at
//  the bottom left, y increasing upwards. So `chinY < eyeLineY < crownY`.
//

import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PDFKit
import Vision

enum PassportPhotoError: LocalizedError, Equatable {

    /// Vision found no face. Not an internal failure and not phrased as one:
    /// the only person who can fix it is holding the camera.
    case noFaceFound
    /// More than one. Cropping to "the biggest" would silently make an identity
    /// photo of whoever happened to be closer to the lens.
    case multipleFaces
    case detectionFailed
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .noFaceFound:
            return String(localized: "No face was found in this photo. Use a photo taken from the front, with the whole head in frame.")
        case .multipleFaces:
            return String(localized: "There is more than one face in this photo. An identity photo has to show one person alone.")
        case .detectionFailed, .renderFailed:
            return String(localized: "Internal Error. Please try again later")
        }
    }
}

/// Where the head is, in the photograph's own pixels.
struct PassportFaceGeometry: Equatable {

    /// Bottom of the chin.
    let chinY: CGFloat
    /// Top of the head, hair included.
    let crownY: CGFloat
    /// The pupils' line.
    let eyeLineY: CGFloat
    /// Halfway between the pupils — what the frame is centred on, rather than
    /// the middle of the face rectangle, which drifts with a turned head.
    let centreX: CGFloat
    /// Widest part of the face contour.
    let faceWidth: CGFloat
    /// Vision's face rectangle, kept for the checks that sample the face only.
    let faceRect: CGRect
    let imageExtent: CGRect

    /// `false` when the crown was inferred from proportions rather than read off
    /// the silhouette. The checklist tells the user which one it was.
    let crownWasMeasured: Bool

    let rollDegrees: CGFloat
    let yawDegrees: CGFloat
    let pitchDegrees: CGFloat
    /// Vision's own opinion of the shot, 0…1. `nil` when it did not offer one.
    let captureQuality: CGFloat?
    /// Eyelid opening over eye width. Around 0.3 open, under 0.15 shut.
    let eyeOpenness: CGFloat?
    /// Inner-lip opening over mouth width. Near zero closed.
    let mouthOpenness: CGFloat?

    var headHeight: CGFloat { max(self.crownY - self.chinY, 1) }
}

enum PassportPhotoUtility {

    /// Its own context, with intermediates uncached: the measurements below
    /// render dozens of one-pixel images and none of them is ever reused.
    private static let context = CIContext(options: [.name: "passport", .cacheIntermediates: false])

    // MARK: - Finding the head

    /// Vision's face observation, or an error the user can act on.
    static func faceObservation(for image: CIImage) async throws -> FaceObservation {
        let handler = ImageRequestHandler(image)
        let faces: [FaceObservation]
        do {
            faces = try await handler.perform(DetectFaceLandmarksRequest())
        } catch {
            throw PassportPhotoError.detectionFailed
        }
        guard !faces.isEmpty else { throw PassportPhotoError.noFaceFound }
        // A second face has to be *a face*, not a pattern on the wallpaper: the
        // detector's low-confidence hits would otherwise refuse perfectly good
        // photographs taken in a busy room.
        let confident = faces.filter { $0.confidence > 0.5 }
        guard confident.count <= 1 else { throw PassportPhotoError.multipleFaces }
        guard let face = confident.first ?? faces.first else { throw PassportPhotoError.noFaceFound }
        return face
    }

    /// Measures the head. `mask` is the subject silhouette from
    /// `BackgroundRemovalUtility`; without it the crown is estimated.
    static func geometry(for face: FaceObservation,
                         in image: CIImage,
                         mask: CIImage?) -> PassportFaceGeometry {
        let extent = image.extent
        let size = extent.size
        let origin = extent.origin

        let faceRect = face.boundingBox
            .toImageCoordinates(size, origin: .lowerLeft)
            .offsetBy(dx: origin.x, dy: origin.y)

        let landmarks = face.landmarks
        let contour = landmarks?.faceContour.pointsInImageCoordinates(size, origin: .lowerLeft)
            .map { CGPoint(x: $0.x + origin.x, y: $0.y + origin.y) } ?? []

        // The chin is the lowest point of the jaw outline. Falling back to the
        // face rectangle's bottom edge costs a millimetre or two, which matters
        // on a 45 mm print — hence the landmarks request rather than the cheaper
        // rectangles one.
        let chinY = contour.map(\.y).min() ?? faceRect.minY
        let faceWidth: CGFloat = {
            guard let minX = contour.map(\.x).min(), let maxX = contour.map(\.x).max(), maxX > minX else {
                return faceRect.width
            }
            return maxX - minX
        }()

        let pupils = [landmarks?.leftPupil, landmarks?.rightPupil]
            .compactMap { $0 }
            .flatMap { $0.pointsInImageCoordinates(size, origin: .lowerLeft) }
            .map { CGPoint(x: $0.x + origin.x, y: $0.y + origin.y) }
        let eyePoints = pupils.isEmpty
            ? [landmarks?.leftEye, landmarks?.rightEye]
                .compactMap { $0 }
                .flatMap { $0.pointsInImageCoordinates(size, origin: .lowerLeft) }
                .map { CGPoint(x: $0.x + origin.x, y: $0.y + origin.y) }
            : pupils

        // Six tenths up the face rectangle is where the eyes sit when Vision
        // gives no landmarks at all — a poor substitute, but the alternative is
        // refusing a photograph the detector was otherwise happy with.
        let eyeLineY = eyePoints.isEmpty
            ? faceRect.minY + faceRect.height * 0.6
            : eyePoints.map(\.y).reduce(0, +) / CGFloat(eyePoints.count)
        let centreX = eyePoints.isEmpty
            ? faceRect.midX
            : eyePoints.map(\.x).reduce(0, +) / CGFloat(eyePoints.count)

        let measuredCrown = mask.flatMap {
            self.topOfSubject(in: $0, around: faceRect, extent: extent)
        }
        // The estimate is the floor, never a ceiling: a silhouette that reports
        // the crown *below* the proportional guess is a segmentation that lost
        // the hair, and trusting it would print a head 4 mm too short.
        let estimatedCrown = chinY + (eyeLineY - chinY) / (1 - PassportPhotoSpec.eyeShareOfHeadHeight)
        let crownY: CGFloat
        let crownWasMeasured: Bool
        if let measuredCrown, measuredCrown > estimatedCrown {
            // Nor is it unbounded: a raised arm or a hat brim in the band would
            // otherwise become the top of the head. Half the face height of hair
            // is more than anyone has.
            crownY = min(measuredCrown, estimatedCrown + faceRect.height * 0.5)
            crownWasMeasured = true
        } else {
            crownY = estimatedCrown
            crownWasMeasured = false
        }

        return PassportFaceGeometry(
            chinY: chinY,
            crownY: crownY,
            eyeLineY: eyeLineY,
            centreX: centreX,
            faceWidth: faceWidth,
            faceRect: faceRect,
            imageExtent: extent,
            crownWasMeasured: crownWasMeasured,
            rollDegrees: CGFloat(face.roll.converted(to: .degrees).value),
            yawDegrees: CGFloat(face.yaw.converted(to: .degrees).value),
            pitchDegrees: CGFloat(face.pitch.converted(to: .degrees).value),
            captureQuality: face.captureQuality.map { CGFloat($0.score) },
            eyeOpenness: self.openness(of: [landmarks?.leftEye, landmarks?.rightEye], in: size, origin: origin),
            mouthOpenness: self.openness(of: [landmarks?.innerLips], in: size, origin: origin))
    }

    /// Height over width of a landmark region, averaged over the regions given.
    /// Both eyelids and lips are measured the same way; what differs is the
    /// number that counts as shut.
    private static func openness(of regions: [FaceObservation.Landmarks2D.Region?],
                                 in size: CGSize,
                                 origin: CGPoint) -> CGFloat? {
        let ratios: [CGFloat] = regions.compactMap { region in
            guard let region else { return nil }
            let points = region.pointsInImageCoordinates(size, origin: .lowerLeft)
            guard points.count >= 3,
                  let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                  let minY = points.map(\.y).min(), let maxY = points.map(\.y).max(),
                  maxX > minX else { return nil }
            return (maxY - minY) / (maxX - minX)
        }
        guard !ratios.isEmpty else { return nil }
        return ratios.reduce(0, +) / CGFloat(ratios.count)
    }

    /// The topmost row of the silhouette in a band around the head.
    ///
    /// Found by bisection over `CIAreaMaximum` rather than by walking a bitmap,
    /// which keeps the whole thing in Core Image's coordinate space. Reading
    /// pixels back would mean knowing which way round the buffer runs, and
    /// getting that wrong finds the shoulders instead of the hair — a bug that
    /// would look like a plausible photo, not like a crash.
    private static func topOfSubject(in mask: CIImage, around faceRect: CGRect, extent: CGRect) -> CGFloat? {
        // Wider than the face, because hair is: 0.9 of the face width either
        // side of centre. Wider still would start catching a raised shoulder.
        let halfWidth = faceRect.width * 0.9
        let minX = max(extent.minX, faceRect.midX - halfWidth)
        let maxX = min(extent.maxX, faceRect.midX + halfWidth)
        guard maxX > minX, extent.maxY > faceRect.midY else { return nil }

        // Working small: bisection costs a dozen evaluations and none of them
        // needs the mask's own resolution.
        let scaled = ScanImageProcessor.downscaled(mask, maxDimension: 512)
        let scale = scaled.extent.height / max(extent.height, 1)
        let band = { (bottom: CGFloat) -> CGRect in
            CGRect(x: (minX - extent.minX) * scale + scaled.extent.minX,
                   y: (bottom - extent.minY) * scale + scaled.extent.minY,
                   width: (maxX - minX) * scale,
                   height: (extent.maxY - bottom) * scale)
        }

        var low = faceRect.midY
        var high = extent.maxY
        guard self.hasCoverage(scaled, in: band(low)) else { return nil }
        // 1/512 of the image is finer than the crown can be defined anyway.
        for _ in 0..<12 {
            let mid = (low + high) / 2
            if self.hasCoverage(scaled, in: band(mid)) {
                low = mid
            } else {
                high = mid
            }
        }
        return low
    }

    /// Whether any pixel of the mask inside `rect` belongs to the subject.
    private static func hasCoverage(_ mask: CIImage, in rect: CGRect) -> Bool {
        let clipped = rect.intersection(mask.extent)
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else { return false }
        let filter = CIFilter.areaMaximum()
        filter.inputImage = mask
        filter.extent = clipped
        guard let output = filter.outputImage else { return false }
        var pixel: [UInt8] = [0, 0, 0, 0]
        self.context.render(output,
                            toBitmap: &pixel,
                            rowBytes: 4,
                            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                            format: .RGBA8,
                            colorSpace: nil)
        return pixel[0] > 128
    }

    /// Mean colour over a region, 0…1 per channel. The validator's only way of
    /// asking a question about the pixels.
    static func averageColour(of image: CIImage, in rect: CGRect) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        let clipped = rect.intersection(image.extent)
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = clipped
        guard let output = filter.outputImage else { return nil }
        var pixel: [UInt8] = [0, 0, 0, 0]
        self.context.render(output,
                            toBitmap: &pixel,
                            rowBytes: 4,
                            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                            format: .RGBA8,
                            colorSpace: nil)
        return (CGFloat(pixel[0]) / 255, CGFloat(pixel[1]) / 255, CGFloat(pixel[2]) / 255)
    }

    // MARK: - The frame

    /// Where to cut, for a given country's rules.
    ///
    /// The rectangle is the *ideal* one and may fall outside the photograph —
    /// that is deliberate. Clamping it here would quietly print a head of the
    /// wrong size; the caller checks whether it fits and either fills the
    /// overflow with the chosen backdrop or refuses, which are the only two
    /// honest answers.
    static func cropRect(for spec: PassportPhotoSpec, geometry: PassportFaceGeometry) -> CGRect {
        let height = geometry.headHeight / spec.targetFaceFraction
        let width = height * spec.aspectRatio

        // The crown's distance from the top edge, as the spec derives it — from
        // an eye line where the country states one, from the head's placement
        // where it does not.
        let top = geometry.crownY + spec.crownFractionFromTop * height
        return CGRect(x: geometry.centreX - width / 2,
                      y: top - height,
                      width: width,
                      height: height)
    }

    // MARK: - Rendering

    /// The finished photo: subject cut out, backdrop painted, cropped to the
    /// country's frame and scaled to its resolution.
    ///
    /// A crop that runs past the edge of the photograph is filled with the
    /// backdrop — legitimate when the backdrop is being replaced anyway, and it
    /// rescues the very common photo with too little room above the head. With
    /// `background: nil` the original pixels are kept and the overflow would be
    /// transparent, so the caller must have refused already.
    static func render(_ image: CIImage,
                       mask: CIImage?,
                       crop: CGRect,
                       spec: PassportPhotoSpec,
                       background: CGColor?,
                       dpi: Int? = nil) -> UIImage? {
        let composed: CIImage
        if let background, let colour = BackgroundRemovalUtility.ciColor(from: background) {
            let backdrop = CIImage(color: colour).cropped(to: crop)
            let subject = mask.map { BackgroundRemovalUtility.composite(image, mask: $0, background: background) }
                ?? image
            // Cropping the subject first and compositing after is what makes the
            // overflow work: the crop shrinks to whatever the photograph
            // actually covers, and the backdrop — which covers the whole frame —
            // fills the rest.
            composed = subject.cropped(to: crop).composited(over: backdrop)
        } else {
            // No backdrop, but the frame is still the frame. Compositing over an
            // empty image cropped to it keeps the geometry right when the crop
            // runs past the photograph: without this the extent shrinks to
            // whatever pixels exist, the scale below is computed from the wrong
            // height, and the preview shows a head of the wrong size — on the
            // one path where the framing check has already refused to export.
            composed = image.cropped(to: crop).composited(over: CIImage(color: .clear).cropped(to: crop))
        }
        guard !composed.extent.isEmpty, composed.extent.height > 0 else { return nil }

        let pixelSize = spec.pixelSize(dpi: dpi ?? spec.minimumDPI)
        let scale = pixelSize.height / composed.extent.height
        let scaled = composed
            .transformed(by: CGAffineTransform(translationX: -composed.extent.minX,
                                               y: -composed.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Clamped before the final crop: rounding the millimetres to whole
        // pixels leaves a sub-pixel sliver, and unclamped that sliver renders as
        // a transparent line down one edge of the print.
        let output = scaled.clampedToExtent().cropped(to: CGRect(origin: .zero, size: pixelSize))
        guard let cgImage = self.context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    // MARK: - Print sheets

    /// Sheets a photo can be tiled onto.
    enum SheetFormat: String, CaseIterable, Identifiable {

        /// What a kiosk and a photo shop print. The reason the feature exists:
        /// six passport photos for the price of one 10 × 15 print.
        case tenByFifteen
        case a4
        case letter

        var id: String { self.rawValue }

        /// Millimetres.
        var size: CGSize {
            switch self {
            case .tenByFifteen: return CGSize(width: 100, height: 150)
            case .a4: return CGSize(width: 210, height: 297)
            case .letter: return CGSize(width: 215.9, height: 279.4)
            }
        }

        var title: String {
            switch self {
            case .tenByFifteen: return String(localized: "10 × 15 cm")
            case .a4: return "A4"
            case .letter: return String(localized: "US Letter")
            }
        }

        var subtitle: String {
            switch self {
            case .tenByFifteen: return String(localized: "Photo shop or kiosk")
            case .a4, .letter: return String(localized: "Home printer")
            }
        }

        /// A4 at 600 dpi is a 35-megapixel bitmap, which is 140 MB of RGBA and a
        /// jettisoned app on an older phone. 300 dpi is past what an inkjet
        /// resolves anyway; the small kiosk print keeps the full resolution.
        var maximumDPI: Int {
            switch self {
            case .tenByFifteen: return 600
            case .a4, .letter: return 300
            }
        }

        /// What to offer, and in what order. The kiosk print first because it is
        /// the cheaper answer, then the one sheet of paper the user's own
        /// printer is loaded with — offering both A4 and Letter would be two
        /// choices where every person on earth only has one.
        static func available(for spec: PassportPhotoSpec) -> [SheetFormat] {
            let letterCountries: Set<String> = ["US", "CA", "MX", "PH"]
            let home: SheetFormat = letterCountries.contains(spec.regionCode ?? "") ? .letter : .a4
            return [.tenByFifteen, home]
        }

        static func `default`(for spec: PassportPhotoSpec) -> SheetFormat {
            self.available(for: spec).first ?? .tenByFifteen
        }
    }

    /// Margin around the sheet and gap between photos, in millimetres. The gap
    /// is what leaves something to cut along without slicing a neighbour.
    private static let sheetMargin: CGFloat = 4
    private static let sheetGap: CGFloat = 3

    /// Lays as many copies of `photo` on a sheet as fit, with cut guides.
    ///
    /// `dpi` overrides the print resolution, for the preview: a thumbnail of an
    /// A4 page has no use for eight megapixels, and building one on every tap
    /// would make the format picker stutter.
    static func printSheet(of photo: UIImage,
                           spec: PassportPhotoSpec,
                           format: SheetFormat,
                           dpi overrideDPI: Int? = nil) -> UIImage? {
        let dpi = overrideDPI ?? min(spec.minimumDPI, format.maximumDPI)
        let millimetre = CGFloat(dpi) / 25.4
        let sheetPixels = CGSize(width: (format.size.width * millimetre).rounded(),
                                 height: (format.size.height * millimetre).rounded())
        let photoPixels = CGSize(width: spec.size.width * millimetre, height: spec.size.height * millimetre)
        guard photoPixels.width > 0, photoPixels.height > 0 else { return nil }

        let usable = CGSize(width: sheetPixels.width - 2 * self.sheetMargin * millimetre,
                            height: sheetPixels.height - 2 * self.sheetMargin * millimetre)
        let gap = self.sheetGap * millimetre
        let columns = max(Int((usable.width + gap) / (photoPixels.width + gap)), 1)
        let rows = max(Int((usable.height + gap) / (photoPixels.height + gap)), 1)

        let gridWidth = CGFloat(columns) * photoPixels.width + CGFloat(columns - 1) * gap
        let gridHeight = CGFloat(rows) * photoPixels.height + CGFloat(rows - 1) * gap
        // Centred rather than pushed into a corner: a sheet that is off-centre
        // reads as a printing mistake even when every photo on it is correct.
        let originX = (sheetPixels.width - gridWidth) / 2
        let originY = (sheetPixels.height - gridHeight) / 2

        let renderer = UIGraphicsImageRenderer(size: sheetPixels, format: {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true
            return format
        }())
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: sheetPixels))
            for row in 0..<rows {
                for column in 0..<columns {
                    let rect = CGRect(x: originX + CGFloat(column) * (photoPixels.width + gap),
                                      y: originY + CGFloat(row) * (photoPixels.height + gap),
                                      width: photoPixels.width,
                                      height: photoPixels.height)
                    photo.draw(in: rect)
                    // A hairline, not a dashed border: it has to survive being
                    // printed and still be invisible once the photo is cut out.
                    UIColor(white: 0.72, alpha: 1).setStroke()
                    let guides = UIBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5))
                    guides.lineWidth = max(millimetre * 0.15, 1)
                    guides.stroke()
                }
            }
        }
    }

    /// How many photos a sheet holds, without drawing it — for the label under
    /// the format picker.
    static func photosPerSheet(spec: PassportPhotoSpec, format: SheetFormat) -> Int {
        let usable = CGSize(width: format.size.width - 2 * self.sheetMargin,
                            height: format.size.height - 2 * self.sheetMargin)
        let columns = max(Int((usable.width + self.sheetGap) / (spec.size.width + self.sheetGap)), 1)
        let rows = max(Int((usable.height + self.sheetGap) / (spec.size.height + self.sheetGap)), 1)
        return columns * rows
    }

    #if DEBUG
    /// A head where a head would be, for looking at the screen on a simulator.
    ///
    /// Vision refuses to run there at all — no inference context — so without
    /// this the tool could only ever be seen as an error alert. It is never a
    /// fallback on a device: an identity photo cropped around an imaginary face
    /// is worse than no photo, and the person would only find out at the
    /// counter.
    static func debugPlaceholderGeometry(for image: CIImage) -> PassportFaceGeometry {
        // Deliberately the same oval `debugPlaceholderMask` draws — inset 20% of
        // the width and 15% of the height. Two placeholders that disagree with
        // each other produce a preview whose guide lines sit nowhere near the
        // shape on screen, which looks exactly like the bug this screen exists
        // to prevent.
        let extent = image.extent
        let chinY = extent.minY + extent.height * 0.15
        let crownY = extent.minY + extent.height * 0.85
        let headHeight = crownY - chinY
        let faceWidth = extent.width * 0.6
        let centreX = extent.midX
        return PassportFaceGeometry(
            chinY: chinY,
            crownY: crownY,
            eyeLineY: crownY - headHeight * PassportPhotoSpec.eyeShareOfHeadHeight,
            centreX: centreX,
            faceWidth: faceWidth,
            faceRect: CGRect(x: centreX - faceWidth / 2, y: chinY, width: faceWidth, height: headHeight * 0.8),
            imageExtent: extent,
            crownWasMeasured: false,
            rollDegrees: 0,
            yawDegrees: 0,
            pitchDegrees: 0,
            captureQuality: nil,
            eyeOpenness: 0.3,
            mouthOpenness: 0.05)
    }
    #endif

    // MARK: - PDF

    /// A one-page PDF at the true physical size.
    ///
    /// Not `PDFUtility.convertUiImageToPdf`: that one makes the page as big as
    /// the bitmap, so a 600 dpi photo becomes a page two feet across and prints
    /// at whatever scale the driver picks. An identity photo is only correct at
    /// one size, so the page is built in points — 35 × 45 mm, and nothing about
    /// the print dialog can change that.
    static func pdf(from image: UIImage, millimetres: CGSize) -> PDFDocument? {
        let points = CGSize(width: millimetres.width / 25.4 * 72, height: millimetres.height / 25.4 * 72)
        let bounds = CGRect(origin: .zero, size: points)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var mediaBox = bounds
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil),
              let cgImage = image.cgImage else { return nil }
        pdfContext.beginPage(mediaBox: &mediaBox)
        pdfContext.draw(cgImage, in: bounds)
        pdfContext.endPage()
        pdfContext.closePDF()
        return PDFDocument(data: data as Data)
    }
}
