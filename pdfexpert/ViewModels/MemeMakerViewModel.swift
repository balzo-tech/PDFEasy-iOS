//
//  MemeMakerViewModel.swift
//  PdfExpert
//
//  "Meme maker": words on a picture, put where the user puts them.
//
//  The tool exists for a reason no other tool in this app has: its output is
//  meant to leave. Every other export here ends in a file the user keeps — this
//  one ends in a share sheet, and that is the number worth watching.
//
//  It began as a form — two text fields under the picture, one line locked to
//  the top and one to the bottom — and that was wrong. A meme is not a document
//  with a caption: the words belong *on* the image, wherever the joke needs
//  them. So the state here is a list of blocks, each carrying its own place and
//  size as **fractions of the image**, and the screen is a canvas that drags
//  them.
//
//  Nothing is burned into a bitmap until the export. The editor draws live text
//  over the picture, which is what makes dragging cost nothing; the file is
//  rendered once, at full resolution, from the very same fractions. See
//  `ImageCanvasUtility.Caption`.
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
    /// Held here rather than in the view so the grid keeps reading the list as it
    /// arrives: opened while the catalogue was still in flight, a view that had
    /// captured an empty array stayed empty for good.
    @Published var browseAllShow: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var savedToPhotosAlertShow: Bool = false
    @Published var photosPermissionAlertShow: Bool = false
    @Published var error: MemeMakerError? = nil
    @Published var shareUrl: ShareableImage? = nil

    /// The blocks of text. Two to begin with, where the format puts them — but
    /// neither is pinned there, and there can be more.
    @Published var captions: [ImageCanvasUtility.Caption] = []
    /// Which block has the handles and the keyboard. Nil means the canvas shows
    /// the picture alone, which is also how the export looks.
    @Published var selectedCaptionId: UUID? = nil

    @Published var color: MemeTextColor = .white
    @Published var isUppercased: Bool = true

    /// The picture, downscaled for the canvas, **without** captions: the editor
    /// draws those live on top, so this only changes when the picture does.
    @Published private(set) var canvasImage: UIImage? = nil

    @Published private(set) var templates: [MemeTemplate] = []
    @Published private(set) var selectedTemplateId: String? = nil
    @Published private(set) var isLoadingTemplate: Bool = false

    var isEmpty: Bool { self.source == nil }

    /// Nothing to export until there is a picture with something to read on it.
    var canExport: Bool {
        self.source != nil && self.captions.contains { !$0.isBlank }
    }

    var style: ImageCanvasUtility.CaptionStyle {
        ImageCanvasUtility.CaptionStyle(fill: self.color.fill,
                                        stroke: self.color.stroke,
                                        isUppercased: self.isUppercased)
    }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    @Injected(\.configService) private var configService

    /// The picture at its own resolution, which is what the file is made from.
    private var source: UIImage? = nil

    private var pendingExport: PendingExport? = nil
    private var onCreatePdf: ((UIImage) -> Void)? = nil
    /// Called once for **any** export that worked, not just the PDF one.
    /// Without it the home funnel would count this tool as finished only when it
    /// ends in a document, which is the one ending it is least likely to have.
    private var onFinished: (() -> Void)? = nil

    /// Big enough to stay sharp on any phone, small enough that swapping template
    /// is instant. The canvas never shows more than this.
    private static let canvasMaxDimension: CGFloat = 1400

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
        self.canvasImage = image.downscaled(maxDimension: Self.canvasMaxDimension)
        // The first picture brings the two blocks the format expects. Changing
        // template afterwards keeps whatever is written and wherever it was put:
        // trying three pictures should not cost three typings.
        if self.captions.isEmpty {
            self.captions = [
                ImageCanvasUtility.Caption(center: CGPoint(x: 0.5, y: 0.12)),
                ImageCanvasUtility.Caption(center: CGPoint(x: 0.5, y: 0.88))
            ]
            self.selectedCaptionId = self.captions.first?.id
        }
    }

    // MARK: - The blocks

    @MainActor
    func addCaption() {
        // Dropped in the middle: visible, and not on top of the two that the
        // first picture already put at the edges.
        let caption = ImageCanvasUtility.Caption(center: CGPoint(x: 0.5, y: 0.5))
        self.captions.append(caption)
        self.selectedCaptionId = caption.id
    }

    @MainActor
    func removeCaption(id: UUID) {
        self.captions.removeAll { $0.id == id }
        if self.selectedCaptionId == id {
            self.selectedCaptionId = nil
        }
    }

    @MainActor
    func select(captionId: UUID?) {
        self.selectedCaptionId = captionId
    }

    /// Moves a block. `translation` is a fraction of the canvas, so the caller
    /// never has to know the picture's real size.
    @MainActor
    func move(captionId: UUID, by translation: CGSize) {
        guard let index = self.captions.firstIndex(where: { $0.id == captionId }) else { return }
        var center = self.captions[index].center
        // Clamped so a block cannot be dragged off the picture and lost. The
        // margin is not zero: a centre exactly on the edge would put half the
        // words outside the frame.
        center.x = min(max(center.x + translation.width, 0.08), 0.92)
        center.y = min(max(center.y + translation.height, 0.06), 0.94)
        self.captions[index].center = center
    }

    @MainActor
    func scale(captionId: UUID, to scale: CGFloat) {
        guard let index = self.captions.firstIndex(where: { $0.id == captionId }) else { return }
        self.captions[index].scale = min(max(scale, 0.04), 0.30)
    }

    func caption(id: UUID) -> ImageCanvasUtility.Caption? {
        self.captions.first { $0.id == id }
    }

    /// A binding to one block's text, so the canvas can hold a field over it.
    @MainActor
    func textBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.captions.first(where: { $0.id == id })?.text ?? "" },
            set: { [weak self] newValue in
                guard let self, let index = self.captions.firstIndex(where: { $0.id == id }) else { return }
                self.captions[index].text = newValue
            }
        )
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

    // MARK: - Getting the result out

    @MainActor
    func saveToPhotos() { self.gate(.photos) }

    @MainActor
    func share() { self.gate(.share) }

    @MainActor
    func createPdf() {
        guard self.canExport else { return }
        self.selectedCaptionId = nil
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
        // The handles belong to the editor, not to the meme: leaving a block
        // selected while the share sheet opens shows the user a picture with a
        // dashed box drawn round the words.
        self.selectedCaptionId = nil
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

    /// `lines` says how many blocks carried words, `template` which picture, and
    /// `destination` whether the thing ever leaves — which is the whole
    /// experiment.
    private func trackCompletion(destination: String) {
        self.analyticsManager.track(event: .memeCompleted(lines: self.captions.filter { !$0.isBlank }.count,
                                                          template: self.selectedTemplateId ?? "own_photo",
                                                          destination: destination))
        self.onFinished?()
    }

    #if DEBUG
    /// Fills the editor in so the canvas can be looked at on a simulator, where
    /// the template strip cannot be tapped from a script. Waits for the
    /// catalogue rather than assuming it has landed.
    @MainActor
    func debugFillForScreenshot() {
        Task { @MainActor in
            for _ in 0..<40 {
                if let first = self.templates.first {
                    self.select(first)
                    break
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
            for _ in 0..<40 {
                if !self.isEmpty { break }
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard self.captions.count >= 2 else { return }
            self.captions[0].text = "when the build is green"
            self.captions[1].text = "but nobody looked at the screen"
            self.selectedCaptionId = self.captions.first?.id
        }
    }
    #endif

    @MainActor
    private func reset() {
        self.source = nil
        self.canvasImage = nil
        self.captions = []
        self.selectedCaptionId = nil
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
