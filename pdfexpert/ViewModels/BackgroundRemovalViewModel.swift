//
//  BackgroundRemovalViewModel.swift
//  PdfExpert
//
//  "Remove background": lift the subject out of a photograph and put a plain
//  backdrop behind it — or nothing at all.
//
//  Vision is asked once, when the photo arrives, and the mask is kept. Switching
//  backdrop after that is a blend, not a second segmentation: the expensive step
//  is the one the user cannot see, and re-running it on every tap would make the
//  cheap step feel expensive too.
//
//  Two resolutions live side by side for the same reason. What is on screen is
//  built from a downscaled copy so a preset switches instantly; what leaves the
//  app is built from the original pixels. Core Image is lazy, so both are the
//  same recipe evaluated at a different size rather than two pipelines.
//

import Foundation
import Factory
import SwiftUI
import CoreImage

extension Container {
    var backgroundRemovalViewModel: Factory<BackgroundRemovalViewModel> {
        self { BackgroundRemovalViewModel() }
    }
}

/// The backdrops on offer.
///
/// White, grey and blue are the three an identity document will accept, which is
/// what this tool shares with the passport-photo work; transparent is what makes
/// the cut-out useful anywhere else.
enum BackgroundRemovalStyle: String, CaseIterable, Identifiable {

    case transparent
    case white
    case grey
    case blue
    case black

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .transparent: return String(localized: "Transparent")
        case .white: return String(localized: "White")
        case .grey: return String(localized: "Grey")
        case .blue: return String(localized: "Blue")
        case .black: return String(localized: "Black")
        }
    }

    /// What goes behind the subject. `nil` keeps the transparency.
    var cgColor: CGColor? {
        switch self {
        case .transparent: return nil
        case .white: return UIColor.white.cgColor
        case .grey: return UIColor(white: 0.85, alpha: 1).cgColor
        case .blue: return UIColor(red: 0.71, green: 0.82, blue: 0.92, alpha: 1).cgColor
        case .black: return UIColor.black.cgColor
        }
    }

    var isTransparent: Bool { self.cgColor == nil }

    /// Transparency only survives PNG. Writing a cut-out as JPEG flattens it
    /// onto black, which reads as a tool that did the opposite of its name.
    var fileExtension: String { self.isTransparent ? "png" : "jpg" }
}

class BackgroundRemovalViewModel: ObservableObject {

    /// What the user asked for, held while the paywall is up so the purchase can
    /// finish the job instead of dropping the user back on the editor.
    enum PendingExport {
        case photos
        case share
    }

    @Published var editorShow: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var savedToPhotosAlertShow: Bool = false
    @Published var photosPermissionAlertShow: Bool = false
    @Published var error: BackgroundRemovalError? = nil
    @Published var shareUrl: ShareableImage? = nil

    @Published var style: BackgroundRemovalStyle = .transparent {
        didSet {
            guard oldValue != self.style else { return }
            Task { @MainActor in self.updatePreview() }
        }
    }

    /// How hard the cut is: 0 keeps every wisp of hair and some background with
    /// it, 1 pulls the edge inside and takes the halo away with the finest
    /// strands. On screen because the right answer is a property of the
    /// photograph, not of the app — hair against a bright wall needs more than a
    /// passport held over a desk.
    @Published var edgeStrength: CGFloat = BackgroundRemovalUtility.defaultEdgeStrength {
        didSet {
            guard oldValue != self.edgeStrength else { return }
            Task { @MainActor in self.updateEdges() }
        }
    }

    /// What the editor draws. Nil while Vision is still working.
    @Published private(set) var previewImage: UIImage? = nil
    @Published private(set) var isProcessing: Bool = false

    var canExport: Bool { self.mask != nil && !self.isProcessing }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store

    /// The photograph and its subject mask, at full resolution. The mask is kept
    /// as Vision returned it: the edge treatment is re-applied to *this* every
    /// time the dial moves, so the choke never compounds on itself.
    private var source: CIImage? = nil
    private var rawMask: CIImage? = nil
    private var mask: CIImage? = nil
    /// The same three, downscaled once for everything the screen shows.
    private var previewSource: CIImage? = nil
    private var rawPreviewMask: CIImage? = nil
    private var previewMask: CIImage? = nil

    private var pendingExport: PendingExport? = nil
    private var onCreatePdf: ((UIImage) -> Void)? = nil

    /// Wide enough to fill a 13" iPad in landscape, small enough that a blend is
    /// instant. Above this the preview costs more than the export.
    private static let previewMaxDimension: CGFloat = 1600

    // MARK: - Running the tool

    /// Entry point: a photograph has been picked, camera or library or file.
    ///
    /// `onCreatePdf` is how the tool hands its result back to the app it lives
    /// in — a cut-out becomes a document through the same path as any other
    /// image, rather than through a second copy of that code here.
    @MainActor
    func run(image: UIImage, onCreatePdf: ((UIImage) -> Void)?) {
        self.onCreatePdf = onCreatePdf
        self.reset()
        self.editorShow = true
        self.analyticsManager.track(event: .reportScreen(.backgroundRemoval))
        self.analyticsManager.track(event: .backgroundRemovalStarted)
        self.removeBackground(from: image)
    }

    @MainActor
    private func removeBackground(from image: UIImage) {
        guard let source = ScanImageProcessor.ciImage(from: image) else {
            self.fail(with: .renderFailed)
            return
        }
        self.source = source
        self.previewSource = ScanImageProcessor.downscaled(source, maxDimension: Self.previewMaxDimension)
        self.isProcessing = true

        Task { @MainActor in
            do {
                // Segmentation on the full-resolution photo: the mask is scaled
                // down for the preview afterwards, never the other way round —
                // a mask found on a thumbnail and blown up has a staircase for
                // an outline.
                let raw = try await BackgroundRemovalUtility.subjectMask(for: source)
                self.rawMask = raw
                self.rawPreviewMask = ScanImageProcessor.downscaled(raw, maxDimension: Self.previewMaxDimension)
                self.isProcessing = false
                self.updateEdges()
            } catch let error as BackgroundRemovalError {
                #if targetEnvironment(simulator) && DEBUG
                // The simulator has no segmentation model, so the tool could
                // never be looked at there. An oval stands in for the subject.
                if error == .maskFailed {
                    let raw = BackgroundRemovalUtility.debugPlaceholderMask(for: source)
                    self.rawMask = raw
                    self.rawPreviewMask = ScanImageProcessor.downscaled(raw, maxDimension: Self.previewMaxDimension)
                    self.isProcessing = false
                    self.updateEdges()
                    return
                }
                #endif
                self.fail(with: error)
            } catch {
                self.fail(with: .maskFailed)
            }
        }
    }

    @MainActor
    private func fail(with error: BackgroundRemovalError) {
        self.isProcessing = false
        self.editorShow = false
        self.error = error
    }

    /// Re-cuts both masks from the untouched one and redraws. Vision is not
    /// asked again: moving the dial is a filter chain, not a segmentation.
    @MainActor
    private func updateEdges() {
        guard let rawMask, let rawPreviewMask else { return }
        self.mask = BackgroundRemovalUtility.refined(rawMask, strength: self.edgeStrength)
        self.previewMask = BackgroundRemovalUtility.refined(rawPreviewMask, strength: self.edgeStrength)
        self.updatePreview()
    }

    @MainActor
    private func updatePreview() {
        guard let previewSource, let previewMask else { return }
        self.previewImage = ScanImageProcessor.uiImage(from:
            BackgroundRemovalUtility.composite(previewSource,
                                               mask: previewMask,
                                               background: self.style.cgColor)
        )
    }

    // MARK: - Getting the result out

    /// Both ways out are gated, for the same reason every other export is: the
    /// work is free to try and paid to keep. A purchase resumes what was asked
    /// for rather than dropping the user back on the editor to ask again.
    @MainActor
    func saveToPhotos() {
        self.gate(.photos)
    }

    @MainActor
    func share() {
        self.gate(.share)
    }

    @MainActor
    func createPdf() {
        guard let image = self.fullResolutionResult() else { return }
        self.trackCompletion(destination: "pdf")
        self.editorShow = false
        // The host presents the editor for the new document; giving it the stage
        // takes a runloop turn, or the presentation is dropped.
        DispatchQueue.main.async { self.onCreatePdf?(image) }
    }

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
        }
    }

    @MainActor
    private func saveToPhotos(_ image: UIImage) {
        Task { @MainActor in
            do {
                try await PhotoLibrarySaver.save(images: [image],
                                                 keepingTransparency: self.style.isTransparent)
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
        guard let data = self.style.isTransparent ? image.pngData()
                                                  : image.jpegData(compressionQuality: K.Misc.ScanJpegQuality) else {
            self.error = .renderFailed
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("image-no-background")
            .appendingPathExtension(self.style.fileExtension)
        do {
            try data.write(to: url)
            self.shareUrl = ShareableImage(url: url, thumbnail: image)
            self.trackCompletion(destination: "share")
        } catch {
            self.error = .renderFailed
        }
    }

    /// The result at the photograph's own resolution — what the preview promises,
    /// evaluated for real.
    @MainActor
    private func fullResolutionResult() -> UIImage? {
        guard let source = self.source, let mask = self.mask else { return nil }
        return ScanImageProcessor.uiImage(from:
            BackgroundRemovalUtility.composite(source, mask: mask, background: self.style.cgColor)
        )
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
        self.analyticsManager.track(event: .backgroundRemovalCompleted(style: self.style.rawValue,
                                                                       destination: destination))
    }

    @MainActor
    private func reset() {
        self.source = nil
        self.rawMask = nil
        self.mask = nil
        self.previewSource = nil
        self.rawPreviewMask = nil
        self.previewMask = nil
        self.edgeStrength = BackgroundRemovalUtility.defaultEdgeStrength
        self.previewImage = nil
        self.pendingExport = nil
        self.isProcessing = false
        self.style = .transparent
    }
}

/// A file on its way to the share sheet, with something for the sheet's header.
struct ShareableImage: Identifiable {
    let id = UUID()
    let url: URL
    let thumbnail: UIImage
}
