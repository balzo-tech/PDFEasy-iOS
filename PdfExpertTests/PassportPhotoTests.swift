//
//  PassportPhotoTests.swift
//  PdfExpertTests
//
//  The identity photo, checked where a mistake costs the user a refused document
//  rather than a redraw: the arithmetic that places the head inside the frame,
//  the catalog of country rules, and the checks that decide whether the user is
//  told to try again.
//
//  Vision is not asserted on here for the same reason it is not in
//  `BackgroundRemovalUtilityTests` — what a detector finds in a drawn fixture is
//  not a promise Apple makes. The geometry is fed in directly instead, which is
//  also the only way to test a head that is tilted fifteen degrees without
//  photographing one.
//

import XCTest
import CoreImage
import UIKit
@testable import PdfExpert

final class PassportPhotoTests: XCTestCase {

    private let size = CGSize(width: 400, height: 400)

    // MARK: - Fixtures

    /// The European 35 × 45, which most of the catalog is a variation on.
    private var europeanSpec: PassportPhotoSpec {
        XCTUnwrapOrFail(PassportPhotoCatalog.spec(withId: "icao.35x45"))
    }

    /// The American 2 × 2, the only shape in the catalog that states an eye line.
    private var americanSpec: PassportPhotoSpec {
        XCTUnwrapOrFail(PassportPhotoCatalog.spec(withId: "us.passport"))
    }

    private func XCTUnwrapOrFail(_ spec: PassportPhotoSpec?) -> PassportPhotoSpec {
        guard let spec else {
            XCTFail("The catalog is missing a specification the tests depend on")
            return PassportPhotoCatalog.all[0]
        }
        return spec
    }

    /// A head 170 px tall, centred, well inside a 400 px frame.
    private func makeGeometry(chinY: CGFloat = 110,
                              crownY: CGFloat = 280,
                              centreX: CGFloat = 200,
                              roll: CGFloat = 0,
                              yaw: CGFloat = 0,
                              pitch: CGFloat = 0,
                              eyeOpenness: CGFloat? = 0.3,
                              mouthOpenness: CGFloat? = 0.04,
                              crownWasMeasured: Bool = true,
                              extent: CGRect? = nil) -> PassportFaceGeometry {
        let frame = extent ?? CGRect(origin: .zero, size: self.size)
        let faceHeight = (crownY - chinY) * 0.72
        return PassportFaceGeometry(
            chinY: chinY,
            crownY: crownY,
            // 47% of the way down from the crown, which is where the utility
            // puts it when it has to guess and where a real face has it.
            eyeLineY: crownY - (crownY - chinY) * PassportPhotoSpec.eyeShareOfHeadHeight,
            centreX: centreX,
            faceWidth: faceHeight * 0.72,
            faceRect: CGRect(x: centreX - faceHeight * 0.36, y: chinY, width: faceHeight * 0.72, height: faceHeight),
            imageExtent: frame,
            crownWasMeasured: crownWasMeasured,
            rollDegrees: roll,
            yawDegrees: yaw,
            pitchDegrees: pitch,
            captureQuality: 0.6,
            eyeOpenness: eyeOpenness,
            mouthOpenness: mouthOpenness)
    }

    private static var rendererFormat: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return format
    }

    private func makePhoto(_ colour: UIColor = UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)) -> CIImage {
        let image = UIGraphicsImageRenderer(size: self.size, format: Self.rendererFormat).image { context in
            colour.setFill()
            context.fill(CGRect(origin: .zero, size: self.size))
        }
        return CIImage(cgImage: image.cgImage!)
    }

    /// A silhouette covering the middle column of the frame, standing in for a
    /// person: everything outside it is background.
    private func makeSubjectMask() -> CIImage {
        let image = UIGraphicsImageRenderer(size: self.size, format: Self.rendererFormat).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: self.size))
            UIColor.white.setFill()
            context.fill(CGRect(x: 120, y: 40, width: 160, height: 360))
        }
        return BackgroundRemovalUtility.normalizedMask(CIImage(cgImage: image.cgImage!))
    }

    private struct Pixel {
        let r: Int, g: Int, b: Int, a: Int
        var isOpaque: Bool { self.a == 255 }
    }

    private func pixel(of image: UIImage, atX x: Int, y: Int) -> Pixel {
        guard let cgImage = image.cgImage else { return Pixel(r: -1, g: -1, b: -1, a: -1) }
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &bytes,
                                width: 1, height: 1,
                                bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        // Drawing the whole image offset so that the pixel of interest lands on
        // the single-pixel context. `y` counts down from the top, as the bitmap
        // does.
        context?.draw(cgImage, in: CGRect(x: -CGFloat(x), y: -CGFloat(cgImage.height - y - 1),
                                          width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        return Pixel(r: Int(bytes[0]), g: Int(bytes[1]), b: Int(bytes[2]), a: Int(bytes[3]))
    }

    // MARK: - The catalog

    func testEverySpecificationHasAHeadThatFitsInsideItsOwnFrame() {
        for spec in PassportPhotoCatalog.all {
            XCTAssertGreaterThan(spec.size.width, 0, "\(spec.id) has no width")
            XCTAssertGreaterThan(spec.size.height, 0, "\(spec.id) has no height")
            XCTAssertLessThan(spec.faceHeight.upperBound, spec.size.height,
                              "\(spec.id) asks for a head taller than the photo")
            XCTAssertGreaterThan(spec.faceHeight.lowerBound, spec.size.height * 0.4,
                                 "\(spec.id) asks for a head so small the frame would be mostly background")
            XCTAssertGreaterThanOrEqual(spec.crownFractionFromTop, 0,
                                        "\(spec.id) puts the crown above the top edge")
            XCTAssertLessThanOrEqual(spec.chinFractionFromTop, 1,
                                     "\(spec.id) puts the chin below the bottom edge")
        }
    }

    func testSpecificationIdentifiersAreUnique() {
        // The id is what the last choice is remembered by, so a duplicate would
        // silently switch a returning user's country.
        let ids = PassportPhotoCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Two specifications share an id")
    }

    func testTheAmericanEyeLineLandsInsideItsOwnPermittedBand() {
        let spec = self.americanSpec
        guard let band = spec.eyeLineFractionFromTop else {
            return XCTFail("The American specification is supposed to state an eye line")
        }
        // Where the crop maths actually puts the eyes: the crown, plus the share
        // of the head height the eye line sits at.
        let eyes = spec.crownFractionFromTop + spec.targetFaceFraction * PassportPhotoSpec.eyeShareOfHeadHeight
        XCTAssertGreaterThanOrEqual(eyes, band.lowerBound - 0.01,
                                    "The head placement puts the eyes above the permitted band")
        XCTAssertLessThanOrEqual(eyes, band.upperBound + 0.01,
                                 "The head placement puts the eyes below the permitted band")
    }

    func testSpainKeepsItsOwnSizeRatherThanTheEuropeanOne() {
        // The one entry it would be easiest to get wrong by copying its
        // neighbours, and the one the Spanish market searches for.
        let spain = self.XCTUnwrapOrFail(PassportPhotoCatalog.spec(withId: "es.dni"))
        XCTAssertEqual(spain.size, CGSize(width: 26, height: 32))
        XCTAssertNotEqual(spain.size, CGSize(width: 35, height: 45))
    }

    func testBritainAsksForAShorterHeadThanTheContinent() {
        let britain = self.XCTUnwrapOrFail(PassportPhotoCatalog.spec(withId: "gb.passport"))
        XCTAssertEqual(britain.size, self.europeanSpec.size, "Same frame")
        XCTAssertLessThan(britain.faceHeight.upperBound, self.europeanSpec.faceHeight.upperBound,
                          "…but a shorter head, which is the whole trap")
    }

    func testSearchFindsACountryByTheWordPeopleActuallyType() {
        let all = PassportPhotoCatalog.all
        XCTAssertEqual(PassportPhotoCatalog.search("fototessera", in: all).first?.regionCode, "IT")
        XCTAssertEqual(PassportPhotoCatalog.search("foto carnet", in: all).first?.regionCode, "ES")
        XCTAssertEqual(PassportPhotoCatalog.search("passbild", in: all).first?.regionCode, "DE")
        XCTAssertFalse(PassportPhotoCatalog.search("3x4", in: all).isEmpty,
                       "The Brazilian format is searched for by its size, never by its name")
    }

    func testSearchIgnoresAccentsAndCase() {
        let all = PassportPhotoCatalog.all
        XCTAssertFalse(PassportPhotoCatalog.search("PHOTO IDENTITE", in: all).isEmpty)
    }

    func testTheDefaultSpecificationFollowsTheRegionRatherThanTheLanguage() {
        // Somebody reading the app in English in Milan needs the Italian format.
        let italian = PassportPhotoCatalog.default(for: Locale(identifier: "en_IT"))
        XCTAssertEqual(italian.regionCode, "IT")
        // And a region nobody has measured falls back to the standard, not to
        // whichever entry happens to be first alphabetically.
        let unknown = PassportPhotoCatalog.default(for: Locale(identifier: "en_NZ"))
        XCTAssertNil(unknown.regionCode)
    }

    // MARK: - Placing the head

    func testTheCropHasTheProportionsTheCountryAsksFor() {
        let spec = self.europeanSpec
        let crop = PassportPhotoUtility.cropRect(for: spec, geometry: self.makeGeometry())
        XCTAssertEqual(crop.width / crop.height, spec.aspectRatio, accuracy: 0.001)
    }

    func testTheHeadFillsExactlyTheShareOfTheFrameTheCountryAsksFor() {
        let spec = self.europeanSpec
        let geometry = self.makeGeometry()
        let crop = PassportPhotoUtility.cropRect(for: spec, geometry: geometry)

        let share = geometry.headHeight / crop.height
        XCTAssertEqual(share, spec.targetFaceFraction, accuracy: 0.001)
        // And that share, turned back into millimetres, is inside the country's
        // own tolerance — which is the number the clerk holds a ruler against.
        let millimetres = share * spec.size.height
        XCTAssertTrue(spec.faceHeight.contains(millimetres),
                      "\(millimetres) mm is outside \(spec.faceHeight)")
    }

    func testTheFrameIsCentredOnTheEyesRatherThanOnTheImage() {
        // A head off to one side has to take the frame with it, or the print
        // shows a person leaning out of their own photo.
        let geometry = self.makeGeometry(centreX: 130)
        let crop = PassportPhotoUtility.cropRect(for: self.europeanSpec, geometry: geometry)
        XCTAssertEqual(crop.midX, 130, accuracy: 0.001)
    }

    func testTheAmericanRuleFollowsItsEyeLineRatherThanTheDefaultPlacement() {
        // The two countries state the rule differently — one measures from the
        // eyes, the other places the head in the frame — and this is the
        // assertion that they were not quietly collapsed into the same maths.
        let spec = self.americanSpec
        let byEyeLine = spec.crownFractionFromTop
        let byDefaultPlacement = (1 - spec.targetFaceFraction) * spec.crownMarginShare
        XCTAssertLessThan(byEyeLine, byDefaultPlacement,
                          "The eye line pushes the head higher than the generic placement would")
        // …while the European entry, which states no eye line, uses exactly that
        // generic placement.
        let european = self.europeanSpec
        XCTAssertEqual(european.crownFractionFromTop,
                       (1 - european.targetFaceFraction) * european.crownMarginShare,
                       accuracy: 0.0001)
    }

    func testTheHeadFillsLessOfTheSquareAmericanFrameThanOfTheEuropeanOne() {
        // 2 × 2 inches with a 30 mm head is a lot more paper around the face
        // than 35 × 45 with a 34 mm one. Getting this backwards would print a
        // head that fills an American frame edge to edge.
        XCTAssertLessThan(self.americanSpec.targetFaceFraction, self.europeanSpec.targetFaceFraction)
    }

    func testABiggerHeadInThePhotographProducesABiggerCrop() {
        let small = PassportPhotoUtility.cropRect(for: self.europeanSpec,
                                                  geometry: self.makeGeometry(chinY: 150, crownY: 250))
        let large = PassportPhotoUtility.cropRect(for: self.europeanSpec,
                                                  geometry: self.makeGeometry(chinY: 60, crownY: 330))
        XCTAssertGreaterThan(large.height, small.height)
        XCTAssertEqual(large.width / large.height, small.width / small.height, accuracy: 0.001)
    }

    // MARK: - Rendering

    func testTheRenderComesOutAtThePrintSize() {
        let spec = self.europeanSpec
        let geometry = self.makeGeometry()
        let crop = PassportPhotoUtility.cropRect(for: spec, geometry: geometry)
        let result = PassportPhotoUtility.render(self.makePhoto(),
                                                 mask: self.makeSubjectMask(),
                                                 crop: crop,
                                                 spec: spec,
                                                 background: UIColor.white.cgColor,
                                                 dpi: 300)
        let expected = spec.pixelSize(dpi: 300)
        XCTAssertEqual(result?.size.width ?? 0, expected.width, accuracy: 1)
        XCTAssertEqual(result?.size.height ?? 0, expected.height, accuracy: 1)
    }

    func testAFrameThatRunsOffTheEdgeIsFilledWithTheChosenBackdrop() throws {
        // The photograph with too little room above the head is the single most
        // common one, and painting the missing strip is what rescues it. If this
        // regresses the strip comes out transparent, which JPEG then flattens to
        // black along one edge of the print.
        let spec = self.europeanSpec
        let geometry = self.makeGeometry(chinY: 20, crownY: 380)
        let crop = PassportPhotoUtility.cropRect(for: spec, geometry: geometry)
        XCTAssertFalse(geometry.imageExtent.contains(crop),
                       "The fixture is supposed to overflow the photograph")

        let result = try XCTUnwrap(PassportPhotoUtility.render(self.makePhoto(),
                                                               mask: self.makeSubjectMask(),
                                                               crop: crop,
                                                               spec: spec,
                                                               background: UIColor.white.cgColor,
                                                               dpi: 150))
        let top = self.pixel(of: result, atX: Int(result.size.width / 2), y: 1)
        XCTAssertTrue(top.isOpaque, "The strip above the head must not be transparent")
        XCTAssertGreaterThan(top.r, 240, "…and it must be the backdrop that was asked for")
        XCTAssertGreaterThan(top.g, 240)
        XCTAssertGreaterThan(top.b, 240)
    }

    func testAGreyBackdropIsNotRenderedAsBlack() throws {
        // `UIColor(white:)` is a *grey* CGColor, and Core Image fills the frame
        // with black when handed one. The background-removal tool was bitten by
        // exactly this; the conversion is shared so that it cannot happen twice.
        let spec = self.europeanSpec
        let geometry = self.makeGeometry()
        let crop = PassportPhotoUtility.cropRect(for: spec, geometry: geometry)
        let grey = try XCTUnwrap(PassportBackground.lightGrey.cgColor)
        let result = try XCTUnwrap(PassportPhotoUtility.render(self.makePhoto(),
                                                               mask: self.makeSubjectMask(),
                                                               crop: crop,
                                                               spec: spec,
                                                               background: grey,
                                                               dpi: 150))
        let corner = self.pixel(of: result, atX: 2, y: 2)
        XCTAssertGreaterThan(corner.r, 200, "The corner is backdrop, and the backdrop is light grey")
    }

    // MARK: - Print sheets

    func testSixEuropeanPhotosFitOnATenByFifteen() {
        // The number the whole feature is sold on: one kiosk print instead of
        // six from a booth.
        XCTAssertEqual(PassportPhotoUtility.photosPerSheet(spec: self.europeanSpec, format: .tenByFifteen), 6)
    }

    func testASmallerPhotoFitsMoreOfThemOnTheSameSheet() {
        let spain = self.XCTUnwrapOrFail(PassportPhotoCatalog.spec(withId: "es.dni"))
        let spanish = PassportPhotoUtility.photosPerSheet(spec: spain, format: .tenByFifteen)
        let european = PassportPhotoUtility.photosPerSheet(spec: self.europeanSpec, format: .tenByFifteen)
        XCTAssertGreaterThan(spanish, european)
    }

    func testTheSheetComesOutAtThePaperSize() {
        let spec = self.europeanSpec
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 350, height: 450),
                                            format: Self.rendererFormat).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 350, height: 450))
        }
        let sheet = PassportPhotoUtility.printSheet(of: photo, spec: spec, format: .tenByFifteen, dpi: 150)
        // 100 × 150 mm at 150 dpi.
        XCTAssertEqual(sheet?.size.width ?? 0, 591, accuracy: 2)
        XCTAssertEqual(sheet?.size.height ?? 0, 886, accuracy: 2)
    }

    func testAmericanSpecificationsAreOfferedAmericanPaper() {
        XCTAssertTrue(PassportPhotoUtility.SheetFormat.available(for: self.americanSpec).contains(.letter))
        XCTAssertFalse(PassportPhotoUtility.SheetFormat.available(for: self.americanSpec).contains(.a4))
        XCTAssertTrue(PassportPhotoUtility.SheetFormat.available(for: self.europeanSpec).contains(.a4))
    }

    // MARK: - The PDF

    func testThePdfPageIsTheTruePhysicalSize() throws {
        // The reason this tool does not go through `PDFUtility`: a page as big
        // as the bitmap prints at whatever scale the driver picks, and an
        // identity photo is only correct at one size.
        let spec = self.europeanSpec
        let photo = UIGraphicsImageRenderer(size: spec.pixelSize(dpi: 300),
                                            format: Self.rendererFormat).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: spec.pixelSize(dpi: 300)))
        }
        let document = try XCTUnwrap(PassportPhotoUtility.pdf(from: photo, millimetres: spec.size))
        let page = try XCTUnwrap(document.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 35 / 25.4 * 72, accuracy: 0.5)
        XCTAssertEqual(bounds.height, 45 / 25.4 * 72, accuracy: 0.5)
    }

    // MARK: - The checks

    private func checks(geometry: PassportFaceGeometry,
                        spec: PassportPhotoSpec? = nil,
                        background: PassportBackground = .white,
                        photo: CIImage? = nil) -> [PassportPhotoCheck] {
        let spec = spec ?? self.europeanSpec
        let crop = PassportPhotoUtility.cropRect(for: spec, geometry: geometry)
        return PassportPhotoValidator.checks(for: spec,
                                             geometry: geometry,
                                             crop: crop,
                                             background: background,
                                             image: photo ?? self.makePhoto(),
                                             imageScale: 1)
    }

    private func outcome(of kind: PassportPhotoCheck.Kind,
                         in checks: [PassportPhotoCheck]) -> PassportPhotoCheck.Outcome? {
        checks.first { $0.id == kind }?.outcome
    }

    func testAFrameThatOverflowsIsRefusedOnlyWhenTheBackgroundIsBeingKept() {
        // The one blocking failure, and the reason it is conditional: with a
        // backdrop being painted there are pixels to put in the overflow, and
        // with the original kept there are not.
        let geometry = self.makeGeometry(chinY: 20, crownY: 380)
        XCTAssertEqual(self.outcome(of: .framing, in: self.checks(geometry: geometry, background: .original)),
                       .failure)
        XCTAssertEqual(self.outcome(of: .framing, in: self.checks(geometry: geometry, background: .white)),
                       .pass)
    }

    func testAHeadCutOffByTheCameraIsRefusedWhateverTheBackdrop() {
        // No backdrop rescues hair that was never photographed.
        let geometry = self.makeGeometry(chinY: 200, crownY: 400)
        XCTAssertEqual(self.outcome(of: .framing, in: self.checks(geometry: geometry, background: .white)),
                       .failure)
    }

    func testATiltedHeadIsAWarningAndABadlyTiltedOneIsAFailure() {
        XCTAssertEqual(self.outcome(of: .pose, in: self.checks(geometry: self.makeGeometry(roll: 1))), .pass)
        XCTAssertEqual(self.outcome(of: .pose, in: self.checks(geometry: self.makeGeometry(roll: 7))), .warning)
        XCTAssertEqual(self.outcome(of: .pose, in: self.checks(geometry: self.makeGeometry(roll: 15))), .failure)
        XCTAssertEqual(self.outcome(of: .pose, in: self.checks(geometry: self.makeGeometry(yaw: 20))), .failure)
    }

    func testASquintIsAWarningButOnlyAShutEyeFails() {
        // Deliberately reluctant: a checklist that refuses passable photographs
        // is one people learn to ignore.
        XCTAssertEqual(self.outcome(of: .eyes, in: self.checks(geometry: self.makeGeometry(eyeOpenness: 0.30))), .pass)
        XCTAssertEqual(self.outcome(of: .eyes, in: self.checks(geometry: self.makeGeometry(eyeOpenness: 0.17))), .warning)
        XCTAssertEqual(self.outcome(of: .eyes, in: self.checks(geometry: self.makeGeometry(eyeOpenness: 0.08))), .failure)
    }

    func testAnOpenMouthIsNeverMoreThanAWarning() {
        XCTAssertEqual(self.outcome(of: .expression, in: self.checks(geometry: self.makeGeometry(mouthOpenness: 0.4))),
                       .warning)
    }

    func testAnEstimatedHeadHeightIsReportedAsSuch() {
        // The honest version of a number the app cannot actually measure — and
        // the advice on it names the control that turns the estimate into a
        // measurement.
        let estimated = self.checks(geometry: self.makeGeometry(crownWasMeasured: false))
        XCTAssertEqual(self.outcome(of: .headSize, in: estimated), .warning)
        XCTAssertNotNil(estimated.first { $0.id == .headSize }?.advice)

        let measured = self.checks(geometry: self.makeGeometry(crownWasMeasured: true))
        XCTAssertEqual(self.outcome(of: .headSize, in: measured), .pass)
    }

    func testAPaintedBackdropIsNotMeasuredAtAll() {
        // There is nothing to measure and no way for it to fail, so the check
        // says so rather than pretending to have looked.
        XCTAssertEqual(self.outcome(of: .background, in: self.checks(geometry: self.makeGeometry(),
                                                                     background: .white)),
                       .pass)
    }

    func testAPatternedBackdropIsCaughtWhenTheOriginalIsKept() throws {
        // Four corners that disagree with each other: the cheap version of
        // "is that a bookshelf behind you".
        let patterned = UIGraphicsImageRenderer(size: self.size, format: Self.rendererFormat).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: self.size))
            UIColor.black.setFill()
            // Split down the middle rather than banded across the top: the
            // samples sit beside the head, so a dark half is what they see
            // wherever the frame lands vertically.
            context.fill(CGRect(x: 0, y: 0, width: self.size.width / 2, height: self.size.height))
        }
        let geometry = self.makeGeometry(chinY: 150, crownY: 250)
        let checks = self.checks(geometry: geometry,
                                 background: .original,
                                 photo: CIImage(cgImage: patterned.cgImage!))
        XCTAssertEqual(self.outcome(of: .background, in: checks), .failure)
    }

    func testAPlainLightBackdropPassesWhenTheOriginalIsKept() {
        let geometry = self.makeGeometry(chinY: 150, crownY: 250)
        let checks = self.checks(geometry: geometry,
                                 background: .original,
                                 photo: self.makePhoto(.white))
        XCTAssertEqual(self.outcome(of: .background, in: checks), .pass)
    }

    func testTheWorstOutcomeIsWhatTheHeaderReports() {
        let checks = self.checks(geometry: self.makeGeometry(roll: 15))
        XCTAssertEqual(PassportPhotoValidator.worstOutcome(in: checks), .failure)
        XCTAssertEqual(checks.first?.outcome, .failure, "Failures are listed first")
    }

    func testAPhotographTooSmallForThePrintIsFlagged() {
        // 170 px of head on a 600 dpi 35 × 45 print is a considerable
        // enlargement, and the user would rather hear it now than see it.
        let checks = self.checks(geometry: self.makeGeometry())
        XCTAssertNotEqual(self.outcome(of: .resolution, in: checks), .pass)
    }
}
