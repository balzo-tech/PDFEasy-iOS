//
//  ScannedPage.swift
//  PdfExpert
//
//  What a scan is made of, before it becomes a PDF: the untouched capture plus
//  the three things the user can change about it — where the page's corners are,
//  which filter is on it, and how it is turned.
//
//  Nothing here is rendered. A page keeps its original frame and describes the
//  edit; `ScanImageProcessor` produces the pixels. That way a correction can be
//  undone, re-applied or changed after the fact without ever degrading the
//  capture, and the whole model stays a cheap value type the UI can diff.
//

import Foundation
import CoreGraphics
import UIKit

// MARK: - Quad

/// The four corners of the page inside the frame, in **normalized image
/// coordinates with the origin at the top left** — the convention SwiftUI and
/// UIKit use, so the crop editor can place its handles without converting.
///
/// Vision hands back its own convention (origin bottom left) and Core Image
/// wants a third one (origin bottom left, in pixels); both conversions live
/// here rather than being repeated at each call site.
struct ScanQuad: Equatable, Hashable, Codable, Sendable {

    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// The whole frame — what a page uses when no document was detected and the
    /// user has not drawn a crop.
    static let full = ScanQuad(topLeft: CGPoint(x: 0, y: 0),
                               topRight: CGPoint(x: 1, y: 0),
                               bottomRight: CGPoint(x: 1, y: 1),
                               bottomLeft: CGPoint(x: 0, y: 1))

    var corners: [CGPoint] { [self.topLeft, self.topRight, self.bottomRight, self.bottomLeft] }

    /// Fraction of the frame the quad covers, by the shoelace formula.
    var area: CGFloat {
        let points = self.corners
        var sum: CGFloat = 0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            sum += current.x * next.y - next.x * current.y
        }
        return abs(sum) / 2
    }

    /// A detection worth acting on. Vision happily returns slivers when it is
    /// looking at a table top: anything under a sixth of the frame, or with a
    /// side shorter than a twentieth of it, is noise rather than a page.
    var isUsable: Bool {
        guard self.area > 0.16 else { return false }
        let points = self.corners
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            if hypot(next.x - current.x, next.y - current.y) < 0.05 { return false }
        }
        return self.isConvex
    }

    /// Rejects self-crossing quads — the shape a user can make by dragging one
    /// handle past its neighbour, which perspective correction cannot resolve.
    var isConvex: Bool {
        let points = self.corners
        var sign: CGFloat = 0
        for index in points.indices {
            let a = points[index]
            let b = points[(index + 1) % points.count]
            let c = points[(index + 2) % points.count]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            if cross == 0 { continue }
            if sign == 0 {
                sign = cross
            } else if (cross > 0) != (sign > 0) {
                return false
            }
        }
        return true
    }

    /// True when the quad is (near enough) the whole frame, so the pipeline can
    /// skip perspective correction entirely.
    var isFullFrame: Bool {
        zip(self.corners, ScanQuad.full.corners).allSatisfy { lhs, rhs in
            abs(lhs.x - rhs.x) < 0.002 && abs(lhs.y - rhs.y) < 0.002
        }
    }

    func clamped() -> ScanQuad {
        func clamp(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        }
        return ScanQuad(topLeft: clamp(self.topLeft),
                        topRight: clamp(self.topRight),
                        bottomRight: clamp(self.bottomRight),
                        bottomLeft: clamp(self.bottomLeft))
    }

    /// Re-labels the corners by position, so "top left" still means the top left
    /// after the user has dragged the handles around. Called when a crop is
    /// confirmed: perspective correction reads the labels, not the geometry, and
    /// swapped labels come out mirrored.
    func normalizedCorners() -> ScanQuad {
        let points = self.corners
        let centerX = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let centerY = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        let top = points.filter { $0.y <= centerY }.sorted { $0.x < $1.x }
        let bottom = points.filter { $0.y > centerY }.sorted { $0.x < $1.x }
        // A degenerate split (all four points on one side of the centre) means
        // the shape is unusable anyway; leave it as it is rather than guessing.
        guard top.count == 2, bottom.count == 2 else { return self }
        return ScanQuad(topLeft: top[0], topRight: top[1], bottomRight: bottom[1], bottomLeft: bottom[0])
    }

    // MARK: Conversions

    /// Points in pixels with the origin at the top left, for drawing.
    func points(in size: CGSize) -> [CGPoint] {
        self.corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    /// Points in pixels with the origin at the **bottom** left, which is what
    /// `CIPerspectiveCorrection` expects.
    func coreImagePoints(in size: CGSize) -> (topLeft: CGPoint, topRight: CGPoint,
                                              bottomRight: CGPoint, bottomLeft: CGPoint) {
        func convert(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
        }
        return (convert(self.topLeft), convert(self.topRight),
                convert(self.bottomRight), convert(self.bottomLeft))
    }
}

// MARK: - Rotation

/// Quarter turns clockwise. Stored as a count rather than an angle so the value
/// stays exact however many times the user taps Rotate.
enum ScanRotation: Int, CaseIterable, Codable, Sendable {

    case none = 0
    case quarter = 1
    case half = 2
    case threeQuarters = 3

    var radians: CGFloat { CGFloat(self.rawValue) * .pi / 2 }

    /// True when the turn swaps width and height.
    var swapsAxes: Bool { self == .quarter || self == .threeQuarters }

    func turnedClockwise() -> ScanRotation {
        ScanRotation(rawValue: (self.rawValue + 1) % 4) ?? .none
    }

    func turnedCounterclockwise() -> ScanRotation {
        ScanRotation(rawValue: (self.rawValue + 3) % 4) ?? .none
    }
}

// MARK: - Filter

/// The looks a scanned page can be given. Deliberately few: a scanner's job is
/// to make a page readable, and every extra option is one more decision between
/// the user and their document.
enum ScanFilter: String, CaseIterable, Identifiable, Codable, Sendable {

    /// The capture as it came off the sensor.
    case original
    /// Colour kept, but flattened and sharpened the way a flatbed scanner would
    /// — the default, and what most captures of a printed page want.
    case document
    /// Neutral grey, for pages where colour carries nothing.
    case grayscale
    /// Two-tone, thresholded per image. Smallest files, best for plain text.
    case blackAndWhite

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .original: return String(localized: "Original")
        case .document: return String(localized: "Document")
        case .grayscale: return String(localized: "Greyscale")
        case .blackAndWhite: return String(localized: "Black & white")
        }
    }

    var systemImage: String {
        switch self {
        case .original: return "photo"
        case .document: return "doc.text.image"
        case .grayscale: return "circle.lefthalf.filled"
        case .blackAndWhite: return "circle.righthalf.filled.inverse"
        }
    }
}

// MARK: - Page

/// One captured page and the edits standing on it.
struct ScannedPage: Identifiable, Equatable, Sendable {

    let id: UUID
    /// The capture, untouched. Every render starts from here.
    let original: UIImage
    /// Where the page sits in the frame. `nil` means "the whole frame" and is
    /// what a capture gets when nothing was detected.
    var quad: ScanQuad?
    var filter: ScanFilter
    var rotation: ScanRotation

    init(id: UUID = UUID(),
         original: UIImage,
         quad: ScanQuad? = nil,
         filter: ScanFilter = .document,
         rotation: ScanRotation = .none) {
        self.id = id
        self.original = original
        self.quad = quad
        self.filter = filter
        self.rotation = rotation
    }

    /// Changes to any of these three mean the rendered pixels are stale. Used as
    /// a cache key, so scrolling a ten-page scan does not re-run Core Image on
    /// pages nobody touched.
    var renderKey: String {
        var hasher = Hasher()
        hasher.combine(self.id)
        hasher.combine(self.quad)
        hasher.combine(self.filter)
        hasher.combine(self.rotation)
        return String(hasher.finalize())
    }

    func rotatedClockwise() -> ScannedPage {
        var page = self
        page.rotation = self.rotation.turnedClockwise()
        return page
    }
}
