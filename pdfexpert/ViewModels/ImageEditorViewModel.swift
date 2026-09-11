//
//  ImageEditorViewModel.swift
//  PdfExpert
//
//  "Edit image": turn it, crop it to a shape, move the three dials.
//
//  The tools it gathers already existed in this app, but only ever pointed at a
//  PDF page — see `in-app-tool-usage`: rotate, crop and compress are each used
//  by a handful of people a month because they are buried inside a document
//  workflow. Here they point at a photograph and give a photograph back.
//
//  Two kinds of crop, on purpose. The shapes are a tap: centred, non-destructive,
//  and the answer to "make this square for the grid". **Crop** is the real one —
//  `ImageCropFlow`, the Mantis cropper this app has used for signatures for two
//  years, with handles, free ratios and its own rotation. Building a second
//  cropper next to a working one would have been the wrong kind of new code.
//
//  The chain is built once and evaluated twice, at preview size and at full
//  size, for the reason `BackgroundRemovalViewModel` sets out: Core Image is
//  lazy, so this costs one description of the work rather than two pipelines.
//

import Foundation
import Factory
import SwiftUI
import CoreImage

extension Container {
    var imageEditorViewModel: Factory<ImageEditorViewModel> {
        self { ImageEditorViewModel() }
    }
}

/// The shapes worth offering. They are the frames people are actually cropping
/// for — a grid, a feed, a story — plus the original, which is the default
/// because most edits here are a turn or a dial, not a recrop.
enum ImageCropShape: String, CaseIterable, Identifiable {

    case original
    case square
    case portrait
    case story
    case landscape

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .original: return String(localized: "Original")
        case .square: return String(localized: "Square")
        case .portrait: return String(localized: "Portrait")
        case .story: return String(localized: "Story")
        case .landscape: return String(localized: "Wide")
        }
    }

    var caption: String? {
        switch self {
        case .original: return nil
        case .square: return "1:1"
        case .portrait: return "4:5"
        case .story: return "9:16"
        case .landscape: return "16:9"
        }
    }

    /// Width over height. `nil` leaves the picture alone.
    var aspect: CGFloat? {
        switch self {
        case .original: return nil
        case .square: return 1
        case .portrait: return 4.0 / 5.0
        case .story: return 9.0 / 16.0
        case .landscape: return 16.0 / 9.0
        }
    }

    var systemImage: String {
        switch self {
        case .original: return "photo"
        case .square: return "square"
        case .portrait: return "rectangle.portrait"
        // Same glyph as the 4:5 one on purpose: the captions underneath say
        // which is which, and the arrow this replaced read as "export".
        case .story: return "rectangle.portrait"
        case .landscape: return "rectangle"
        }
    }
}

class ImageEditorViewModel: ObservableObject {

    enum PendingExport {
        case photos
        case share
    }

    @Published var editorShow: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var savedToPhotosAlertShow: Bool = false
    @Published var photosPermissionAlertShow: Bool = false
    @Published var error: ImageEditorError? = nil
    @Published var shareUrl: ShareableImage? = nil

    @Published private(set) var rotation: ScanRotation = .none
    @Published private(set) var isMirrored: Bool = false

    @Published var shape: ImageCropShape = .original { didSet { self.redraw(oldValue, self.shape) } }
    @Published var brightness: CGFloat = 0 { didSet { self.redraw(oldValue, self.brightness) } }
    @Published var contrast: CGFloat = 0 { didSet { self.redraw(oldValue, self.contrast) } }
    @Published var saturation: CGFloat = 0 { didSet { self.redraw(oldValue, self.saturation) } }

    @Published private(set) var previewImage: UIImage? = nil

    var canExport: Bool { self.source != nil }

    /// True when nothing has been touched — the export is still allowed (people
    /// do use this to get a JPEG out of a HEIC) but the reset button has no work
    /// to do and says so by being disabled.
    var isUntouched: Bool {
        self.rotation == .none && !self.isMirrored && self.shape == .original
            && self.brightness == 0 && self.contrast == 0 && self.saturation == 0
    }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.imageCropFlow) var imageCropFlow

    /// Mantis draws nothing under Catalyst, and `ImageCropFlow` hands the picture
    /// straight back there rather than showing an empty black screen. A button
    /// that silently does nothing is worse than no button, so it is hidden.
    var canCropFreely: Bool { !UIDevice.isMac }

    private var source: CIImage? = nil
    private var previewSource: CIImage? = nil

    private var pendingExport: PendingExport? = nil
    private var onCreatePdf: ((UIImage) -> Void)? = nil
    /// Called once for **any** export that worked, not just the PDF one.
    /// Without it the home funnel would count this tool as finished only
    /// when it ends in a document, which is the one ending it is least
    /// likely to have.
    private var onFinished: (() -> Void)? = nil

    private static let previewMaxDimension: CGFloat = 1600

    // MARK: - Running the tool

    @MainActor
    func run(image: UIImage,
             onCreatePdf: ((UIImage) -> Void)?,
             onFinished: (() -> Void)? = nil) {
        self.onCreatePdf = onCreatePdf
        self.onFinished = onFinished
        self.reset()
        guard let source = ScanImageProcessor.ciImage(from: image) else {
            self.error = .renderFailed
            return
        }
        self.source = source
        self.previewSource = ScanImageProcessor.downscaled(source, maxDimension: Self.previewMaxDimension)
        self.editorShow = true
        self.analyticsManager.track(event: .reportScreen(.imageEditor))
        self.analyticsManager.track(event: .imageEditStarted)
        self.updatePreview()
    }

    // MARK: - The edits

    @MainActor
    func turnClockwise() {
        self.rotation = self.rotation.turnedClockwise()
        self.updatePreview()
    }

    @MainActor
    func turnAnticlockwise() {
        // Three quarters clockwise is one quarter the other way, and there is
        // only one turn primitive to keep in step.
        self.rotation = self.rotation.turnedClockwise().turnedClockwise().turnedClockwise()
        self.updatePreview()
    }

    @MainActor
    func mirror() {
        self.isMirrored.toggle()
        self.updatePreview()
    }

    /// Opens the real cropper on what is currently on screen.
    ///
    /// What comes back **replaces the picture**, and every dial goes back to
    /// zero: the crop is taken of the edit as the user sees it, so keeping the
    /// recipe as well would apply it a second time. Cropping commits.
    @MainActor
    func cropFreely() {
        guard let current = self.fullResolutionResult() else { return }
        self.imageCropFlow.startFlow(image: current, onImageCropped: { [weak self] cropped in
            self?.replaceSource(with: cropped)
        })
    }

    @MainActor
    private func replaceSource(with image: UIImage) {
        guard let source = ScanImageProcessor.ciImage(from: image) else {
            self.error = .renderFailed
            return
        }
        self.source = source
        self.previewSource = ScanImageProcessor.downscaled(source, maxDimension: Self.previewMaxDimension)
        self.rotation = .none
        self.isMirrored = false
        self.shape = .original
        self.brightness = 0
        self.contrast = 0
        self.saturation = 0
        self.updatePreview()
    }

    @MainActor
    func resetEdits() {
        self.rotation = .none
        self.isMirrored = false
        self.shape = .original
        self.brightness = 0
        self.contrast = 0
        self.saturation = 0
        self.updatePreview()
    }

    /// The whole edit, as one description of the work.
    ///
    /// Order matters and is not arbitrary: turn and mirror first because the
    /// crop is expressed against the picture as the user now sees it, colour
    /// last because it is the only step whose result does not depend on the
    /// frame.
    private func chain(from image: CIImage) -> CIImage {
        var out = ScanImageProcessor.turned(image, by: self.rotation)
        if self.isMirrored {
            out = ImageCanvasUtility.mirrored(out)
        }
        out = ImageCanvasUtility.cropped(out, toAspect: self.shape.aspect)
        return ImageCanvasUtility.adjusted(out,
                                           brightness: Float(self.brightness),
                                           contrast: Float(self.contrast),
                                           saturation: Float(self.saturation))
    }

    private func redraw<T: Equatable>(_ old: T, _ new: T) {
        guard old != new else { return }
        Task { @MainActor in self.updatePreview() }
    }

    @MainActor
    private func updatePreview() {
        guard let previewSource else { return }
        self.previewImage = ScanImageProcessor.uiImage(from: self.chain(from: previewSource))
    }

    // MARK: - Getting the result out

    @MainActor
    func saveToPhotos() { self.gate(.photos) }

    @MainActor
    func share() { self.gate(.share) }

    @MainActor
    func createPdf() {
        guard let image = self.fullResolutionResult() else { return }
        self.trackCompletion(destination: "pdf")
        self.editorShow = false
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
        case .photos: self.saveToPhotos(image)
        case .share: self.shareFile(for: image)
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
        guard let data = image.jpegData(compressionQuality: K.Misc.ScanJpegQuality) else {
            self.error = .renderFailed
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("edited-image")
            .appendingPathExtension("jpg")
        do {
            try data.write(to: url)
            self.shareUrl = ShareableImage(url: url, thumbnail: image)
            self.trackCompletion(destination: "share")
        } catch {
            self.error = .renderFailed
        }
    }

    @MainActor
    private func fullResolutionResult() -> UIImage? {
        guard let source else { return nil }
        return ScanImageProcessor.uiImage(from: self.chain(from: source))
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

    /// `shape` says which frames people actually crop for, `destination` whether
    /// the edit ends in a file or in a shrug.
    private func trackCompletion(destination: String) {
        self.analyticsManager.track(event: .imageEditCompleted(shape: self.shape.rawValue,
                                                                destination: destination))
        self.onFinished?()
    }

    @MainActor
    private func reset() {
        self.source = nil
        self.previewSource = nil
        self.previewImage = nil
        self.rotation = .none
        self.isMirrored = false
        self.shape = .original
        self.brightness = 0
        self.contrast = 0
        self.saturation = 0
        self.pendingExport = nil
    }
}

enum ImageEditorError: LocalizedError {

    case renderFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed: return String(localized: "The image could not be edited. Try another photo.")
        }
    }
}
