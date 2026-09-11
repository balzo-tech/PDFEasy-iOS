//
//  MemeMakerViewModel.swift
//  PdfExpert
//
//  "Meme maker": a picture, a line over it, a line under it.
//
//  The tool exists for a reason no other tool in this app has: its output is
//  meant to leave. Every other export here ends in a file the user keeps — this
//  one ends in a share sheet, and that is the number worth watching.
//
//  Like the background remover it keeps two resolutions: the captions are drawn
//  onto a downscaled copy while the user types, and onto the original on the way
//  out. The type size is a fraction of the image height rather than a point
//  size, which is what makes those two agree.
//
//  Unlike every other tool here it does **not** start at the photo picker. A meme
//  usually starts from a template everybody already recognises, so the editor
//  opens on the gallery and the user's own camera roll is one tile in it — see
//  `MemeTemplateCatalog` for where those pictures come from and how to withdraw
//  them.
//

import Foundation
import Factory
import SwiftUI
import UIKit

extension Container {
    var memeMakerViewModel: Factory<MemeMakerViewModel> {
        self { MemeMakerViewModel() }
    }
}

/// The three fills that read on a photograph. White is the format's own, black
/// is for pictures that are mostly bright, yellow is the subtitle look.
enum MemeTextColor: String, CaseIterable, Identifiable {

    case white
    case black
    case yellow

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .white: return String(localized: "White")
        case .black: return String(localized: "Black")
        case .yellow: return String(localized: "Yellow")
        }
    }

    var fill: UIColor {
        switch self {
        case .white: return .white
        case .black: return .black
        case .yellow: return UIColor(red: 1, green: 0.85, blue: 0.1, alpha: 1)
        }
    }

    /// The outline is always the opposite, or the text disappears on the half of
    /// photographs that happen to match it.
    var stroke: UIColor {
        switch self {
        case .white, .yellow: return .black
        case .black: return .white
        }
    }

    var swatch: Color { Color(uiColor: self.fill) }
}

class MemeMakerViewModel: ObservableObject {

    enum PendingExport {
        case photos
        case share
    }

    @Published var editorShow: Bool = false
    /// Held here rather than in the view so the grid keeps reading the list
    /// as it arrives: opened while the catalogue was still in flight, a view
    /// that had captured an empty array stayed empty for good.
    @Published var browseAllShow: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var savedToPhotosAlertShow: Bool = false
    @Published var photosPermissionAlertShow: Bool = false
    @Published var error: MemeMakerError? = nil
    @Published var shareUrl: ShareableImage? = nil

    @Published var topText: String = "" { didSet { self.redrawIfChanged(oldValue, self.topText) } }
    @Published var bottomText: String = "" { didSet { self.redrawIfChanged(oldValue, self.bottomText) } }

    @Published var textScale: CGFloat = 0.11 {
        didSet {
            guard oldValue != self.textScale else { return }
            Task { @MainActor in self.updatePreview() }
        }
    }

    @Published var color: MemeTextColor = .white {
        didSet {
            guard oldValue != self.color else { return }
            Task { @MainActor in self.updatePreview() }
        }
    }

    @Published var isUppercased: Bool = true {
        didSet {
            guard oldValue != self.isUppercased else { return }
            Task { @MainActor in self.updatePreview() }
        }
    }

    @Published private(set) var previewImage: UIImage? = nil

    /// The gallery. Empty when the templates are switched off remotely, or when
    /// the service could not be reached — in both cases the tool falls back to
    /// what it did before: the user's own photograph.
    @Published private(set) var templates: [MemeTemplate] = []
    @Published private(set) var selectedTemplateId: String? = nil
    @Published private(set) var isLoadingTemplate: Bool = false

    /// Nothing to export until there is something to read: a picture with no
    /// caption is the picture the user already had.
    var canExport: Bool {
        self.source != nil && !self.captions.isEmpty
    }

    /// True before any picture has been chosen, template or photograph.
    var isEmpty: Bool { self.source == nil }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.configService) private var configService

    /// The photograph at both sizes. The preview is small enough that redrawing
    /// the captions on every keystroke is free.
    private var source: UIImage? = nil
    private var previewSource: UIImage? = nil

    private var pendingExport: PendingExport? = nil
    private var onCreatePdf: ((UIImage) -> Void)? = nil
    /// Called once for **any** export that worked, not just the PDF one.
    /// Without it the home funnel would count this tool as finished only
    /// when it ends in a document, which is the one ending it is least
    /// likely to have.
    private var onFinished: (() -> Void)? = nil

    private static let previewMaxDimension: CGFloat = 1000

    private var captions: [ImageCanvasUtility.Caption] {
        var out: [ImageCanvasUtility.Caption] = []
        if !self.topText.isEmpty { out.append(.init(text: self.topText, position: .top)) }
        if !self.bottomText.isEmpty { out.append(.init(text: self.bottomText, position: .bottom)) }
        return out
    }

    private var style: ImageCanvasUtility.CaptionStyle {
        ImageCanvasUtility.CaptionStyle(scale: self.textScale,
                                        fill: self.color.fill,
                                        stroke: self.color.stroke,
                                        isUppercased: self.isUppercased)
    }

    // MARK: - Running the tool

    /// Opens the editor on the gallery, with nothing chosen yet.
    @MainActor
    func start(onCreatePdf: ((UIImage) -> Void)?, onFinished: (() -> Void)? = nil) {
        self.onCreatePdf = onCreatePdf
        self.onFinished = onFinished
        self.reset()
        self.editorShow = true
        self.analyticsManager.track(event: .reportScreen(.memeMaker))
        self.analyticsManager.track(event: .memeStarted)
        self.loadTemplates()
    }

    /// A picture the user brought, from the camera roll tile.
    @MainActor
    func use(image: UIImage) {
        self.selectedTemplateId = nil
        self.setSource(image)
    }

    @MainActor
    private func setSource(_ image: UIImage) {
        self.source = image
        self.previewSource = image.downscaled(maxDimension: Self.previewMaxDimension)
        self.updatePreview()
    }

    // MARK: - The gallery

    @MainActor
    private func loadTemplates() {
        let config = self.configService.remoteConfigData.value
        guard config.memeTemplatesEnabled else { return }
        Task { @MainActor in
            self.templates = await MemeTemplateCatalog.shared.templates(allowedIds: config.memeTemplateIds)
        }
    }

    /// Downloads the chosen template and puts it under the words.
    ///
    /// The captions are kept: swapping template is a change of backdrop, the way
    /// the background remover swaps a colour, and retyping the joke for every
    /// picture would make trying three of them cost three times as much.
    @MainActor
    func select(_ template: MemeTemplate) {
        guard let url = template.blankUrl, !self.isLoadingTemplate else { return }
        self.isLoadingTemplate = true
        self.selectedTemplateId = template.id
        Task { @MainActor in
            let image = await MemeTemplateCatalog.image(at: url)
            self.isLoadingTemplate = false
            guard self.selectedTemplateId == template.id else { return }
            guard let image else {
                self.selectedTemplateId = nil
                self.error = .templateUnavailable
                return
            }
            self.setSource(image)
        }
    }

    @MainActor
    private func updatePreview() {
        guard let previewSource else {
            self.previewImage = nil
            return
        }
        self.previewImage = ImageCanvasUtility.captioned(previewSource,
                                                         captions: self.captions,
                                                         style: self.style)
    }

    private func redrawIfChanged(_ old: String, _ new: String) {
        guard old != new else { return }
        Task { @MainActor in self.updatePreview() }
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
            .appendingPathComponent("meme")
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
        return ImageCanvasUtility.captioned(source, captions: self.captions, style: self.style)
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

    /// `lines` says whether people write one caption or two, `destination`
    /// whether the thing ever leaves — the two questions this experiment exists
    /// to answer.
    private func trackCompletion(destination: String) {
        self.analyticsManager.track(event: .memeCompleted(lines: self.captions.count,
                                                          template: self.selectedTemplateId ?? "own_photo",
                                                          destination: destination))
        self.onFinished?()
    }

    @MainActor
    private func reset() {
        self.source = nil
        self.previewSource = nil
        self.previewImage = nil
        self.topText = ""
        self.bottomText = ""
        self.textScale = 0.11
        self.color = .white
        self.isUppercased = true
        self.pendingExport = nil
        self.selectedTemplateId = nil
        self.isLoadingTemplate = false
        self.browseAllShow = false
    }
}

enum MemeMakerError: LocalizedError {

    case renderFailed
    case templateUnavailable

    var errorDescription: String? {
        switch self {
        case .renderFailed: return String(localized: "The image could not be created. Try another photo.")
        case .templateUnavailable: return String(localized: "That template could not be loaded. Check your connection or pick another.")
        }
    }
}

extension UIImage {

    /// A copy no larger than `maxDimension` on its longest side, or the same
    /// image when it already fits.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(self.size.width, self.size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let ratio = maxDimension / longest
        let target = CGSize(width: self.size.width * ratio, height: self.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
