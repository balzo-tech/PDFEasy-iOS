//
//  PassportPhotoViewModel.swift
//  PdfExpert
//
//  "Passport photo": take an ordinary photograph and produce the one the office
//  will accept — right size, right head height, right backdrop — and say plainly
//  what is wrong with it when something is.
//
//  Vision is asked twice when the photo arrives, and never again: once for the
//  face and once for the subject silhouette. Everything after that — changing
//  country, changing backdrop, switching to a print sheet — is arithmetic and a
//  blend over a mask that is already in hand. That is what lets the country
//  picker feel like a switch rather than like a second import.
//
//  Two resolutions, as in `BackgroundRemovalViewModel`: the screen is drawn from
//  a downscaled copy, the print is rendered from the original pixels at the
//  country's own dpi. The checks run on the downscaled copy too — shadows and
//  backdrops are low-frequency and none of those numbers moves when the pixels
//  get smaller.
//

import Foundation
import Factory
import SwiftUI
import CoreImage
import PDFKit

extension Container {
    var passportPhotoViewModel: Factory<PassportPhotoViewModel> {
        self { PassportPhotoViewModel() }
    }
}

class PassportPhotoViewModel: ObservableObject {

    /// What the user asked for, held while the paywall is up so the purchase can
    /// finish the job instead of dropping them back on the editor.
    enum PendingExport {
        case photos
        case share
        case pdf
    }

    /// One photo, or a sheet of them to cut up.
    enum Output: String, CaseIterable, Identifiable {

        case photo
        case sheet

        var id: String { self.rawValue }

        var title: String {
            switch self {
            case .photo: return String(localized: "One photo")
            case .sheet: return String(localized: "Print sheet")
            }
        }
    }

    @Published var editorShow: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var savedToPhotosAlertShow: Bool = false
    @Published var photosPermissionAlertShow: Bool = false
    @Published var specPickerShow: Bool = false
    @Published var error: PassportPhotoError? = nil
    @Published var shareUrl: ShareableImage? = nil

    /// The country and document being made for. Remembered between runs: whoever
    /// needed an Italian passport photo in March needs an Italian one in
    /// September, and re-picking it every time is a tax on the returning user.
    @Published var spec: PassportPhotoSpec = PassportPhotoCatalog.default() {
        didSet {
            guard oldValue != self.spec else { return }
            UserDefaults.standard.set(self.spec.id, forKey: Self.lastSpecKey)
            self.sheetFormat = PassportPhotoUtility.SheetFormat.default(for: self.spec)
            // The country decides which backdrops exist, so changing it can
            // change the backdrop too — and that has its own rebuild. Doing both
            // would run the whole checklist twice on one tap.
            let backdrop = self.availableBackgrounds.first ?? .original
            if backdrop != self.background {
                self.background = backdrop
            } else {
                Task { @MainActor in self.rebuild() }
            }
        }
    }

    @Published var background: PassportBackground = .white {
        didSet {
            guard oldValue != self.background else { return }
            Task { @MainActor in self.rebuild() }
        }
    }

    @Published var output: Output = .photo {
        didSet {
            guard oldValue != self.output else { return }
            Task { @MainActor in self.updatePreview() }
        }
    }

    @Published var sheetFormat: PassportPhotoUtility.SheetFormat = .tenByFifteen {
        didSet {
            // Nothing on screen changes while a single photo is being shown, and
            // the country picker moves this every time it lands on a spec that
            // prints on different paper.
            guard oldValue != self.sheetFormat, self.output == .sheet else { return }
            Task { @MainActor in self.updatePreview() }
        }
    }

    /// The crown, chin and eye lines drawn over the preview. On by default: they
    /// are the evidence that the crop is not a guess, and the first thing
    /// somebody comparing us to a photo booth looks for.
    @Published var showsGuides: Bool = true

    @Published private(set) var previewImage: UIImage? = nil
    @Published private(set) var checks: [PassportPhotoCheck] = []
    @Published private(set) var isProcessing: Bool = false
    /// `false` when the photograph had a face but no silhouette — the backdrop
    /// cannot be replaced, so only "keep original" is offered.
    @Published private(set) var canReplaceBackground: Bool = true

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store

    /// Full resolution: the photograph, the silhouette as Vision returned it and
    /// the silhouette with its edge re-cut. The raw one is kept so the edge
    /// treatment never compounds on itself.
    private var source: CIImage? = nil
    private var mask: CIImage? = nil
    /// The same, downscaled once for the screen and for the measurements.
    private var previewSource: CIImage? = nil
    private var previewMask: CIImage? = nil
    private var previewScale: CGFloat = 1

    private var geometry: PassportFaceGeometry? = nil
    private var crop: CGRect = .zero

    private var pendingExport: PendingExport? = nil
    private var onCreatePdf: ((PDFDocument, String) -> Void)? = nil

    private static let lastSpecKey = "passportPhotoSpecId"
    /// Same cap as the background removal tool, for the same reason: wide enough
    /// to fill an iPad, small enough that a blend is instant.
    private static let previewMaxDimension: CGFloat = 1600
    /// Roughly how tall the on-screen photo is rendered. Rendering the preview at
    /// the print's 600 dpi would cost more than the export it is previewing.
    private static let previewTargetPixels: CGFloat = 900

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.lastSpecKey),
           let spec = PassportPhotoCatalog.spec(withId: stored) {
            self.spec = spec
        }
        self.background = self.spec.backgrounds.first ?? .white
        self.sheetFormat = PassportPhotoUtility.SheetFormat.default(for: self.spec)
    }

    // MARK: - Derived state

    /// The backdrops on offer: what the country allows, minus everything that
    /// needs a silhouette when there is not one.
    var availableBackgrounds: [PassportBackground] {
        guard self.canReplaceBackground else { return [.original] }
        return self.spec.backgrounds
    }

    var sheetFormats: [PassportPhotoUtility.SheetFormat] {
        PassportPhotoUtility.SheetFormat.available(for: self.spec)
    }

    var photosPerSheet: Int {
        PassportPhotoUtility.photosPerSheet(spec: self.spec, format: self.sheetFormat)
    }

    var worstOutcome: PassportPhotoCheck.Outcome {
        PassportPhotoValidator.worstOutcome(in: self.checks)
    }

    var failureCount: Int { self.checks.filter { $0.outcome == .failure }.count }
    var warningCount: Int { self.checks.filter { $0.outcome == .warning }.count }

    /// The one failure that stops the export rather than warning about it.
    ///
    /// Everything else is advice the user is entitled to overrule — plenty of
    /// offices accept a photo this app would grumble about. But a frame that
    /// runs off the edge of a photograph whose background is being kept has no
    /// pixels to put there, and exporting it would write a transparent band down
    /// one side. The advice on that check names the control that fixes it.
    var isExportBlocked: Bool {
        guard let geometry else { return true }
        return !self.background.replacesBackground && !geometry.imageExtent.contains(self.crop)
    }

    var canExport: Bool { self.geometry != nil && !self.isProcessing && !self.isExportBlocked }

    // MARK: - Running the tool

    @MainActor
    func run(image: UIImage, onCreatePdf: ((PDFDocument, String) -> Void)?) {
        self.onCreatePdf = onCreatePdf
        self.reset()
        self.editorShow = true
        self.analyticsManager.track(event: .reportScreen(.passportPhoto))
        self.analyticsManager.track(event: .passportPhotoStarted(spec: self.spec.id))
        self.analyse(image)
    }

    @MainActor
    private func analyse(_ image: UIImage) {
        guard let source = ScanImageProcessor.ciImage(from: image) else {
            self.fail(with: .renderFailed)
            return
        }
        self.source = source
        let preview = ScanImageProcessor.downscaled(source, maxDimension: Self.previewMaxDimension)
        self.previewSource = preview
        self.previewScale = preview.extent.height / max(source.extent.height, 1)
        self.isProcessing = true

        Task { @MainActor in
            do {
                let face = try await PassportPhotoUtility.faceObservation(for: source)
                // The silhouette is wanted, not required: without it the backdrop
                // cannot be replaced and the crown is estimated rather than
                // measured, both of which the checklist reports. Refusing the
                // photograph outright over it would be worse.
                let raw = try? await BackgroundRemovalUtility.subjectMask(for: source)
                self.adopt(mask: raw, source: source)
                self.geometry = PassportPhotoUtility.geometry(for: face, in: source, mask: self.mask)
                self.isProcessing = false
                self.rebuild()
            } catch let error as PassportPhotoError {
                #if targetEnvironment(simulator) && DEBUG
                // No inference context on a simulator, so neither request can
                // run and the screen could never be looked at there. An oval
                // stands in for the head. Never on a device.
                if error == .detectionFailed {
                    self.adopt(mask: BackgroundRemovalUtility.debugPlaceholderMask(for: source), source: source)
                    self.geometry = PassportPhotoUtility.debugPlaceholderGeometry(for: source)
                    self.isProcessing = false
                    self.rebuild()
                    return
                }
                #endif
                self.fail(with: error)
            } catch {
                self.fail(with: .detectionFailed)
            }
        }
    }

    /// Keeps the silhouette at both resolutions, with its edge already re-cut.
    ///
    /// The edge dial the background-removal tool puts on screen is not here on
    /// purpose: an identity photo is a head against a plain wall, which is the
    /// case the default setting was chosen for, and one more control on this
    /// screen would be one more thing between the user and a printable photo.
    @MainActor
    private func adopt(mask raw: CIImage?, source: CIImage) {
        guard let raw else {
            self.mask = nil
            self.previewMask = nil
            self.canReplaceBackground = false
            self.background = .original
            return
        }
        let refined = BackgroundRemovalUtility.refined(raw)
        self.mask = refined
        self.previewMask = ScanImageProcessor.downscaled(refined, maxDimension: Self.previewMaxDimension)
        self.canReplaceBackground = true
    }

    @MainActor
    private func fail(with error: PassportPhotoError) {
        self.isProcessing = false
        self.editorShow = false
        self.error = error
    }

    /// Re-cuts the frame for the current country and re-runs the checks. Vision
    /// is not asked again.
    @MainActor
    private func rebuild() {
        guard let geometry, let previewSource else { return }
        self.crop = PassportPhotoUtility.cropRect(for: self.spec, geometry: geometry)
        self.checks = PassportPhotoValidator.checks(for: self.spec,
                                                    geometry: geometry,
                                                    crop: self.crop,
                                                    background: self.background,
                                                    image: previewSource,
                                                    imageScale: self.previewScale)
        self.updatePreview()
    }

    @MainActor
    private func updatePreview() {
        guard let previewSource, self.geometry != nil else { return }
        let previewCrop = self.crop.applying(CGAffineTransform(scaleX: self.previewScale, y: self.previewScale))
        let dpi = max(Int(Self.previewTargetPixels * 25.4 / self.spec.size.height), 72)
        guard let photo = PassportPhotoUtility.render(previewSource,
                                                      mask: self.previewMask,
                                                      crop: previewCrop,
                                                      spec: self.spec,
                                                      background: self.background.cgColor,
                                                      dpi: min(dpi, self.spec.minimumDPI)) else {
            self.previewImage = nil
            return
        }
        switch self.output {
        case .photo:
            self.previewImage = photo
        case .sheet:
            // A sheet drawn at print resolution is a 35-megapixel bitmap nobody
            // is looking closely at; 150 dpi is plenty for a thumbnail of a page.
            self.previewImage = PassportPhotoUtility.printSheet(of: photo,
                                                                spec: self.spec,
                                                                format: self.sheetFormat,
                                                                dpi: 150) ?? photo
        }
    }

    // MARK: - Getting the result out

    @MainActor
    func saveToPhotos() { self.gate(.photos) }

    @MainActor
    func share() { self.gate(.share) }

    @MainActor
    func createPdf() { self.gate(.pdf) }

    @MainActor
    func onMonetizationClose() {
        let pending = self.pendingExport
        self.pendingExport = nil
        guard self.store.isPremium.value, let pending else { return }
        self.perform(pending)
    }

    @MainActor
    private func gate(_ export: PendingExport) {
        guard self.canExport else { return }
        if self.store.isPremium.value {
            self.perform(export)
        } else {
            self.pendingExport = export
            self.monetizationShow = true
        }
    }

    @MainActor
    private func perform(_ export: PendingExport) {
        guard let image = self.fullResolutionResult() else {
            self.error = .renderFailed
            return
        }
        switch export {
        case .photos:
            self.saveToPhotos(image)
        case .share:
            self.shareFile(for: image)
        case .pdf:
            self.makePdf(from: image)
        }
    }

    /// The print, at the country's own resolution. Everything the preview showed,
    /// evaluated for real.
    @MainActor
    private func fullResolutionResult() -> UIImage? {
        guard let source else { return nil }
        guard let photo = PassportPhotoUtility.render(source,
                                                      mask: self.mask,
                                                      crop: self.crop,
                                                      spec: self.spec,
                                                      background: self.background.cgColor) else { return nil }
        switch self.output {
        case .photo:
            return photo
        case .sheet:
            return PassportPhotoUtility.printSheet(of: photo, spec: self.spec, format: self.sheetFormat)
        }
    }

    @MainActor
    private func saveToPhotos(_ image: UIImage) {
        Task { @MainActor in
            do {
                try await PhotoLibrarySaver.save(images: [image])
                self.savedToPhotosAlertShow = true
                self.trackCompletion(destination: "photos")
            } catch PhotoLibrarySaveError.notAuthorized {
                self.photosPermissionAlertShow = true
            } catch {
                self.error = .renderFailed
            }
        }
    }

    @MainActor
    private func shareFile(for image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            self.error = .renderFailed
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(self.filename)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: url)
            self.shareUrl = ShareableImage(url: url, thumbnail: image)
            self.trackCompletion(destination: "share")
        } catch {
            self.error = .renderFailed
        }
    }

    /// A PDF at the true physical size, so what comes out of the printer is the
    /// size the office asked for whatever the print dialog decides to do.
    @MainActor
    private func makePdf(from image: UIImage) {
        let millimetres = self.output == .sheet ? self.sheetFormat.size : self.spec.size
        guard let document = PassportPhotoUtility.pdf(from: image, millimetres: millimetres) else {
            self.error = .renderFailed
            return
        }
        self.trackCompletion(destination: "pdf")
        self.editorShow = false
        // The host presents the editor for the new document; giving it the stage
        // takes a runloop turn, or the presentation is dropped.
        let filename = self.filename
        DispatchQueue.main.async { self.onCreatePdf?(document, filename) }
    }

    /// What the file is called. The country and the size are in the name because
    /// this is a file somebody emails to a print shop.
    private var filename: String {
        let size = "\(Int(self.spec.size.width.rounded()))x\(Int(self.spec.size.height.rounded()))"
        let region = self.spec.regionCode?.lowercased() ?? "icao"
        let suffix = self.output == .sheet ? "-\(self.sheetFormat.rawValue)" : ""
        return "passport-photo-\(region)-\(size)\(suffix)"
    }

    @MainActor
    func onShareDismiss() {
        if let url = self.shareUrl?.url {
            try? FileManager.default.removeItem(at: url)
        }
        self.shareUrl = nil
    }

    @MainActor
    func cancel() {
        self.editorShow = false
        self.reset()
    }

    // MARK: - Housekeeping

    private func trackCompletion(destination: String) {
        self.analyticsManager.track(event: .passportPhotoCompleted(spec: self.spec.id,
                                                                   destination: destination,
                                                                   output: self.output.rawValue,
                                                                   outcome: String(describing: self.worstOutcome)))
    }

    @MainActor
    private func reset() {
        self.source = nil
        self.mask = nil
        self.previewSource = nil
        self.previewMask = nil
        self.previewScale = 1
        self.geometry = nil
        self.crop = .zero
        self.previewImage = nil
        self.checks = []
        self.pendingExport = nil
        self.isProcessing = false
        self.canReplaceBackground = true
        self.output = .photo
        self.background = self.spec.backgrounds.first ?? .white
    }
}

extension PassportPhotoCheck.Outcome: CustomStringConvertible {

    /// Only for analytics — never shown, so it stays unlocalized on purpose.
    public var description: String {
        switch self {
        case .pass: return "pass"
        case .warning: return "warning"
        case .failure: return "failure"
        }
    }
}
