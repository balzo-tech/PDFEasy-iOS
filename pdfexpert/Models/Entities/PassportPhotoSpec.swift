//
//  PassportPhotoSpec.swift
//  PdfExpert
//
//  What each country asks of an identity photograph: how big the print is, how
//  tall the head has to be inside it, what may be behind it.
//
//  This file is the feature. Cropping a face and painting the backdrop white is
//  an afternoon's work and every competitor has done it; knowing that Spain
//  wants 26×32 mm while everyone else wants 35×45, that the United States
//  measures from the eyes rather than from the crown, and that the United
//  Kingdom's head is shorter than Germany's, is what decides whether the clerk
//  accepts the print. A wrong number here is a refused document and a one-star
//  review, so every entry names the authority it came from and nothing is
//  guessed: where an official source gives no head height, the range is derived
//  from the "70–80% of the frame" rule that ICAO 9303 states and the note says
//  so.
//
//  ⚠️ The app is not the authority and never says it is — offices change their
//  rules and some accept only their own booth. The wording on screen promises a
//  photo built to these measurements, never that it will be accepted.
//

import Foundation
import UIKit

// MARK: - Backdrops

/// What goes behind the subject.
///
/// The three colours are the ones identity documents actually allow between
/// them; `original` keeps the photograph's own background, for the user who
/// already shot against a compliant wall and would rather not have the edge
/// re-cut at all.
enum PassportBackground: String, CaseIterable, Identifiable, Hashable {

    case white
    case lightGrey
    case lightBlue
    case original

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .white: return String(localized: "White")
        case .lightGrey: return String(localized: "Light grey")
        case .lightBlue: return String(localized: "Light blue")
        case .original: return String(localized: "Keep original")
        }
    }

    /// `nil` means "do not replace anything".
    ///
    /// The grey is deliberately light (0.92): offices ask for a *light* neutral
    /// grey, and a mid grey reads as a shadow behind the head on a cheap print.
    var cgColor: CGColor? {
        switch self {
        case .white: return UIColor.white.cgColor
        case .lightGrey: return UIColor(white: 0.92, alpha: 1).cgColor
        case .lightBlue: return UIColor(red: 0.80, green: 0.87, blue: 0.94, alpha: 1).cgColor
        case .original: return nil
        }
    }

    var replacesBackground: Bool { self.cgColor != nil }
}

// MARK: - The specification

struct PassportPhotoSpec: Identifiable, Hashable {

    /// Stable across releases: it is what the last choice is remembered by.
    let id: String
    /// ISO 3166-1 alpha-2, or `nil` for the international standard. Drives the
    /// flag and the country name, so the name comes localized for free.
    let regionCode: String?
    /// What the photo is *for*, in the user's language.
    let documentName: String
    /// Print size in millimetres, width × height.
    let size: CGSize
    /// Chin to crown, in millimetres. The crown is the top of the head *with*
    /// the hair, which is what makes it hard to measure and why the tool uses
    /// the subject silhouette rather than the face rectangle — see
    /// `PassportPhotoUtility.geometry(for:mask:)`.
    let faceHeight: ClosedRange<CGFloat>
    /// Where the eyes must sit, measured from the bottom edge in millimetres.
    ///
    /// Only the United States and the countries that copied its 2×2 inch form
    /// state this; everywhere else the head is simply centred and this is `nil`.
    /// When it is present it wins over `crownMarginShare`: the two rules do not
    /// agree, and the one the office measures is this one.
    let eyeLineFromBottom: ClosedRange<CGFloat>?
    /// Of the vertical space left over once the head is placed, how much goes
    /// *above* the crown. A third above and two thirds below is what every
    /// printed template does, and it is what keeps the shoulders in frame.
    var crownMarginShare: CGFloat = 0.33
    /// In the order they should be offered; the first is the default.
    let backgrounds: [PassportBackground]
    /// What the print has to resolve to. 600 for the European 35×45, which is a
    /// small print inspected closely; 300 where the print is large.
    let minimumDPI: Int
    /// Who says so. Shown under the picker, so the number on screen can be
    /// traced to somebody other than us.
    let authority: String
    /// One line of what is peculiar about this one.
    let note: String?

    // MARK: Derived

    var aspectRatio: CGFloat { self.size.width / self.size.height }

    /// What the tool aims for: the middle of the permitted range, which leaves
    /// the most room for the head-height estimate to be a little wrong in either
    /// direction without falling out of tolerance.
    var targetFaceHeight: CGFloat { (self.faceHeight.lowerBound + self.faceHeight.upperBound) / 2 }

    /// The head's share of the frame's height, which is what the cropping maths
    /// actually works in.
    var targetFaceFraction: CGFloat { self.targetFaceHeight / self.size.height }

    var faceFractionRange: ClosedRange<CGFloat> {
        (self.faceHeight.lowerBound / self.size.height)...(self.faceHeight.upperBound / self.size.height)
    }

    /// Eye line as a fraction of the height measured from the *top*, which is
    /// the direction the preview's guide lines are drawn in.
    var eyeLineFractionFromTop: ClosedRange<CGFloat>? {
        guard let range = self.eyeLineFromBottom else { return nil }
        let high = 1 - range.lowerBound / self.size.height
        let low = 1 - range.upperBound / self.size.height
        return low...high
    }

    /// Where the crown sits, as a fraction of the height from the top.
    var crownFractionFromTop: CGFloat {
        if let eyes = self.eyeLineFractionFromTop {
            // The eye line is roughly halfway down the head; place the crown so
            // that both rules land in the same place on the paper.
            let eyeMid = (eyes.lowerBound + eyes.upperBound) / 2
            return max(0, eyeMid - self.targetFaceFraction * PassportPhotoSpec.eyeShareOfHeadHeight)
        }
        return (1 - self.targetFaceFraction) * self.crownMarginShare
    }

    var chinFractionFromTop: CGFloat { self.crownFractionFromTop + self.targetFaceFraction }

    /// How far down the head the eye line falls, as a share of chin-to-crown.
    ///
    /// A hair under half: the eyes sit at the middle of the skull, and the hair
    /// that the crown includes is all above them. Used to reconcile the two ways
    /// a country can state the rule, and to estimate the crown from landmarks
    /// when the silhouette cannot be trusted.
    static let eyeShareOfHeadHeight: CGFloat = 0.47

    /// Pixel size of the finished photo at a given resolution.
    func pixelSize(dpi: Int) -> CGSize {
        CGSize(width: (self.size.width / 25.4 * CGFloat(dpi)).rounded(),
               height: (self.size.height / 25.4 * CGFloat(dpi)).rounded())
    }

    /// "35 × 45 mm", in the user's number format.
    var sizeDescription: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let width = formatter.string(from: NSNumber(value: Double(self.size.width))) ?? "\(self.size.width)"
        let height = formatter.string(from: NSNumber(value: Double(self.size.height))) ?? "\(self.size.height)"
        return "\(width) × \(height) mm"
    }

    /// The country's own name for itself, in the user's language. `nil` region —
    /// the international standard — has no country to name.
    var countryName: String? {
        guard let regionCode else { return nil }
        return Locale.current.localizedString(forRegionCode: regionCode)
    }

    var displayName: String {
        guard let country = self.countryName else { return self.documentName }
        return "\(country) · \(self.documentName)"
    }

    /// The flag, built from the region code's letters. No image assets, no
    /// licensing, and it follows whatever the system decides a flag looks like.
    var flag: String {
        guard let regionCode, regionCode.count == 2 else { return "🌍" }
        return regionCode.uppercased().unicodeScalars.reduce(into: "") { flag, scalar in
            guard let indicator = UnicodeScalar(127397 + scalar.value) else { return }
            flag.unicodeScalars.append(indicator)
        }
    }

    /// What the picker's search matches on, beyond the visible name: the words
    /// people actually type, in the languages the app ships.
    var searchTerms: [String]
}
