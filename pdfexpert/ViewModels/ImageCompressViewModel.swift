//
//  ImageCompressViewModel.swift
//  PdfExpert
//
//  "Compress images" (free): pick photographs, choose how small, see what it
//  actually costs, then keep them.
//
//  Free for the same reason `PdfCompressUtility`'s tool is: the measured usage of
//  every utility in this app sits between one and nine people a month, so putting
//  one behind the subscription earns nothing and giving it away costs nothing —
//  but a tile that works is a reason to keep the app on the phone.
//
//  Several pictures at once because that is how the job actually arrives: nobody
//  compresses one photograph, they compress the twelve they are about to email.
//  The work is done on a background task, one picture at a time, and each result
//  is written to disk rather than held: fifty compressed pictures in memory is the
//  same mistake as fifty decoded ones, one step later.
//
//  Nothing is overwritten. The originals are never touched — the output is new
//  files, which is what makes "too aggressive" a recoverable mistake.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var imageCompressViewModel: Factory<ImageCompressViewModel> {
        self { ImageCompressViewModel() }
    }
}

/// One picture on its way in: the bytes as they arrived, parked on disk.
struct ImageCompressSource {
    let url: URL
    let filename: String
}

/// One row of the tool: what came in, and what the current settings make of it.
struct ImageCompressItem: Identifiable {

    let id = UUID()
    let source: ImageCompressSource
    let originalByteCount: Int
    let originalPixelSize: CGSize
    let thumbnail: UIImage?

    /// nil while this picture has not been compressed yet under the current
    /// settings — the row shows the original weight and a spinner rather than a
    /// number that belongs to the previous setting.
    var outcome: ImageCompressOutcome?

    /// Set when the encoder refused this picture: without it, a file that cannot
    /// be read is indistinguishable from one still being worked on, and its row
    /// spins for as long as the screen is open. It is still exported — as the
    /// original, which is the honest thing to hand back.
    var didFail: Bool = false

    /// What will be saved: the compressed file when it is smaller, the original
    /// when it is not. A tool that hands back a heavier file has failed at the one
    /// thing it promised, so in that case the original is what leaves.
    var outputUrl: URL {
        guard let outcome, outcome.isSmaller else { return self.source.url }
        return outcome.url
    }

    var outputByteCount: Int {
        guard let outcome, outcome.isSmaller else { return self.originalByteCount }
        return outcome.byteCount
    }
}

struct ImageCompressOutcome {
    let url: URL
    let byteCount: Int
    let pixelSize: CGSize
    let isSmaller: Bool
}

class ImageCompressViewModel: ObservableObject {

    enum Export {
        case photos
        case share
    }

    @Published var editorShow: Bool = false
    @Published var savedToPhotosAlertShow: Bool = false
    @Published var photosPermissionAlertShow: Bool = false
    @Published var error: ImageCompressError? = nil
    @Published var shareUrls: ShareableImages? = nil

    @Published var quality: ImageCompressionQuality = .balanced {
        didSet {
            guard oldValue != self.quality else { return }
            Task { @MainActor in self.compressAll() }
        }
    }

    @Published var size: ImageCompressionSize = .large {
        didSet {
            guard oldValue != self.size else { return }
            Task { @MainActor in self.compressAll() }
        }
    }

    @Published private(set) var items: [ImageCompressItem] = []
    @Published private(set) var isCompressing: Bool = false
    @Published private(set) var progress: Double = 0

    var originalByteCount: Int { self.items.reduce(0) { $0 + $1.originalByteCount } }
    var compressedByteCount: Int { self.items.reduce(0) { $0 + $1.outputByteCount } }

    /// 0…1 over the whole selection. The per-picture numbers are in the rows; this
    /// is the one the decision is made on.
    var savedFraction: Double {
        let original = self.originalByteCount
        guard original > 0, self.compressedByteCount < original else { return 0 }
        return 1 - Double(self.compressedByteCount) / Double(original)
    }

    var isSmaller: Bool { self.compressedByteCount < self.originalByteCount }
    var canExport: Bool { !self.items.isEmpty && !self.isCompressing }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.paywallPrompter) private var paywallPrompter

    private var onFinished: (() -> Void)? = nil
    /// True while Photos is copying the files in. Closing the screen throws the
    /// working directory away, and doing that underneath a save in flight would
    /// lose the very pictures the user just asked to keep.
    private var isSaving: Bool = false
    /// Bumped on every run, so a slow setting finishing late cannot overwrite the
    /// results of the setting the user has since switched to.
    private var runToken: Int = 0

    private static let thumbnailMaxPixelSize: CGFloat = 240

    /// Everything this tool writes lives here and is thrown away wholesale when
    /// the screen closes — the originals it copied in as much as the results.
    private static var workingDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("image-compress", isDirectory: true)
    }

    // MARK: - Running the tool

    /// Copies the bytes of a picked picture into the tool's own directory.
    ///
    /// Static, and called before `run`, because the caller is the one holding the
    /// picker: `HomeViewModel` reads the photographs one at a time as the library
    /// hands them over, and each one is on disk before the next is asked for.
    static func makeSource(data: Data, filename: String?, index: Int) -> ImageCompressSource? {
        let directory = self.workingDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // The name people will see in the share sheet and in Files. The
            // result leaves as a JPEG, so the stem is kept and the extension is
            // replaced — but the copy of the *original* keeps the type it really
            // is, because a picture that turns out not to be worth compressing is
            // shared as it arrived.
            let base = (filename?.isEmpty == false ? filename! : String(localized: "Image \(index + 1)"))
            let stem = (base as NSString).deletingPathExtension
            let url = directory
                .appendingPathComponent("source-\(index)-\(stem)")
                .appendingPathExtension(ImageCompressUtility.fileExtension(for: data))
            try data.write(to: url, options: .atomic)
            return ImageCompressSource(url: url, filename: stem)
        } catch {
            return nil
        }
    }

    @MainActor
    func run(sources: [ImageCompressSource], onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
        guard !sources.isEmpty else {
            self.error = .noImages
            return
        }

        self.items = sources.compactMap { source in
            let byteCount = (try? source.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard let pixelSize = ImageCompressUtility.pixelSize(url: source.url) else { return nil }
            return ImageCompressItem(source: source,
                                     originalByteCount: byteCount,
                                     originalPixelSize: pixelSize,
                                     thumbnail: ImageCompressUtility.thumbnail(url: source.url,
                                                                               maxPixelSize: Self.thumbnailMaxPixelSize),
                                     outcome: nil)
        }

        guard !self.items.isEmpty else {
            self.error = .unreadable
            return
        }

        self.editorShow = true
        self.analyticsManager.track(event: .reportScreen(.imageCompress))
        self.analyticsManager.track(event: .imageCompressStarted(imageCount: self.items.count))
        self.compressAll()
    }

    // MARK: - The work

    @MainActor
    private func compressAll() {
        guard !self.items.isEmpty else { return }

        self.runToken += 1
        let token = self.runToken
        let quality = self.quality
        let size = self.size
        let sources = self.items.map { (id: $0.id, url: $0.source.url, filename: $0.source.filename) }

        self.isCompressing = true
        self.progress = 0
        for index in self.items.indices {
            self.items[index].outcome = nil
            self.items[index].didFail = false
        }

        // The loop stays on the main actor and hands each picture out to a
        // background task, one at a time: the encoder is what has to be off this
        // thread, and running all fifty at once would put every decoded bitmap in
        // memory simultaneously — the thing this whole file is arranged to avoid.
        Task { @MainActor [weak self] in
            for (offset, source) in sources.enumerated() {
                // The settings changed while this was running: whatever is still
                // in flight is now about the wrong question.
                guard let self, self.runToken == token else { return }

                let outcome = await Task.detached(priority: .userInitiated) {
                    Self.compress(source: source.url,
                                  filename: source.filename,
                                  index: offset,
                                  quality: quality,
                                  size: size)
                }.value

                guard self.runToken == token else { return }
                self.apply(outcome, to: source.id,
                           progress: Double(offset + 1) / Double(sources.count))
            }
            self?.finishCompressing(token: token)
        }
    }

    /// Runs one picture and writes the result next to the original. Nothing here
    /// touches the view model, so it is safe off the main actor.
    private static func compress(source: URL,
                                 filename: String,
                                 index: Int,
                                 quality: ImageCompressionQuality,
                                 size: ImageCompressionSize) -> ImageCompressOutcome? {
        guard let result = ImageCompressUtility.compress(url: source, quality: quality, size: size) else {
            return nil
        }
        let url = self.workingDirectory
            .appendingPathComponent("\(index)-\(filename)")
            .appendingPathExtension("jpg")
        do {
            try result.data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        return ImageCompressOutcome(url: url,
                                    byteCount: result.compressedByteCount,
                                    pixelSize: result.pixelSize,
                                    isSmaller: result.isSmaller)
    }

    @MainActor
    private func apply(_ outcome: ImageCompressOutcome?, to id: UUID, progress: Double) {
        if let index = self.items.firstIndex(where: { $0.id == id }) {
            self.items[index].outcome = outcome
            self.items[index].didFail = outcome == nil
        }
        self.progress = progress
    }

    @MainActor
    private func finishCompressing(token: Int) {
        guard self.runToken == token else { return }
        self.isCompressing = false
        self.progress = 1
    }

    // MARK: - Getting the results out

    @MainActor
    func saveToPhotos() {
        guard self.canExport else { return }
        let urls = self.items.map { $0.outputUrl }
        self.isSaving = true
        Task { @MainActor in
            do {
                try await PhotoLibrarySaver.save(imageFiles: urls)
                self.savedToPhotosAlertShow = true
                self.trackCompletion(destination: "photos")
            } catch PhotoLibrarySaveError.notAuthorized {
                self.photosPermissionAlertShow = true
            } catch {
                self.error = .saveFailed
            }
            self.isSaving = false
            // Closed while this was running: nobody cleaned up, because doing so
            // would have pulled the files out from under Photos.
            if !self.editorShow {
                self.cleanUp()
            }
        }
    }

    @MainActor
    func share() {
        guard self.canExport else { return }
        self.shareUrls = ShareableImages(urls: self.items.map { $0.outputUrl },
                                         thumbnail: self.items.first?.thumbnail)
        self.trackCompletion(destination: "share")
    }

    @MainActor
    func onShareDismiss() {
        self.shareUrls = nil
    }

    @MainActor
    func cancel() {
        self.editorShow = false
        self.reset()
    }

    // MARK: - Housekeeping

    /// `quality` and `size` say which of the two dials people actually move,
    /// `saved_percent` whether the answer was worth having, and `destination`
    /// whether the job ended in a file or in a shrug.
    private func trackCompletion(destination: String) {
        self.analyticsManager.track(event: .imageCompressCompleted(
            quality: self.quality,
            size: self.size,
            destination: destination,
            savedPercent: Int((self.savedFraction * 100).rounded()),
            imageCount: self.items.count
        ))
        Task { @MainActor in self.paywallPrompter.actionCompleted() }
        self.onFinished?()
    }

    @MainActor
    private func reset() {
        self.runToken += 1
        self.items = []
        self.isCompressing = false
        self.progress = 0
        self.shareUrls = nil
        if !self.isSaving {
            self.cleanUp()
        }
    }

    /// Everything this tool wrote — the copies of the originals as much as the
    /// results — goes away together.
    private func cleanUp() {
        try? FileManager.default.removeItem(at: Self.workingDirectory)
    }
}

/// Several files for one share sheet. The single-image counterpart lives next to
/// `ImageEditorViewModel`; this one carries the whole selection, because sharing
/// twelve compressed photographs one at a time is not sharing them.
struct ShareableImages: Identifiable {
    var id: String { self.urls.map { $0.absoluteString }.joined() }
    let urls: [URL]
    let thumbnail: UIImage?
}

enum ImageCompressError: LocalizedError {

    case noImages
    case unreadable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noImages: return String(localized: "Choose at least one image to compress.")
        case .unreadable: return String(localized: "Those images could not be read. Try other files.")
        case .saveFailed: return String(localized: "The images could not be saved. Try again.")
        }
    }
}
