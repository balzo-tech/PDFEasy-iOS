//
//  DocumentScanViewModel.swift
//  PdfExpert
//
//  One scanning session: the pages taken so far, the edits standing on each of
//  them, and what happens when the user is done.
//
//  The session outlives the camera screen. Pages are captured, reviewed,
//  re-cropped, re-filtered and reordered against the same array, and only the
//  final Save turns them into a document — which is why a page keeps its
//  original capture instead of being flattened as it arrives.
//
//  Rendering is cached by `ScannedPage.renderKey`: a page whose crop, filter and
//  rotation have not changed is never sent through Core Image twice.
//

import Foundation
import SwiftUI
import Factory
import PDFKit

extension Container {
    var documentScanViewModel: Factory<DocumentScanViewModel> {
        self { DocumentScanViewModel() }
    }
}

/// What the flow does with the pages once the user confirms.
enum ScanFlowMode: Equatable {
    /// Name it, save it to the archive, optionally send the pages to Photos.
    /// This is the Scanner tab's flow.
    case newDocument
    /// Hand the pages straight back to whoever opened the scanner — the editor
    /// appending pages to an open document, or ChatPDF importing one.
    case handOff
}

class DocumentScanViewModel: ObservableObject {

    enum Step: Equatable {
        case capture
        case review
    }

    // MARK: Session

    @Published private(set) var pages: [ScannedPage] = []
    @Published var step: Step = .capture
    /// The page the review screen is showing.
    @Published var currentPageIndex: Int = 0
    @Published var mode: ScanFlowMode = .newDocument
    /// The filter new captures are given. Whatever the user last chose holds for
    /// the rest of the stack: a batch of pages is nearly always the same paper.
    @Published var captureFilter: ScanFilter = .document

    // MARK: Saving

    @Published var saveSheetShow: Bool = false
    @Published var filename: String = ""
    @Published var asyncPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            // The conversion hands back a document; storing it is a separate
            // step, so a failed write shows its own error rather than looking
            // like a failed conversion.
            guard let pdf = self.asyncPdf.data else { return }
            self.store(pdf: pdf)
        }
    }
    @Published var asyncSave: AsyncEmptyFailable<SharedLocalizedError> = .idle
    @Published var photosPermissionDeniedShow: Bool = false
    /// Set once everything is written, so the flow can close and tell the caller.
    @Published private(set) var savedPdf: Pdf? = nil
    @Published private(set) var savedToPhotosCount: Int = 0
    @Published var savedToPhotosAlertShow: Bool = false

    let capture = ScanCaptureService()

    /// Called in `.handOff` mode with the finished pages.
    var onHandOff: (([ScannedPage]) -> Void)? = nil
    /// Called in `.newDocument` mode once the document is in the archive.
    var onSaved: ((Pdf) -> Void)? = nil

    @Injected(\.repository) private var repository
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.mainCoordinator) private var mainCoordinator

    /// Rendered pages, keyed by `ScannedPage.renderKey`.
    private var renderCache: [String: UIImage] = [:]
    private var renderTasks: Set<String> = []

    var currentPage: ScannedPage? {
        guard self.pages.indices.contains(self.currentPageIndex) else { return nil }
        return self.pages[self.currentPageIndex]
    }

    var canFinish: Bool { !self.pages.isEmpty }

    // MARK: - Lifecycle

    func start(mode: ScanFlowMode) {
        self.mode = mode
        self.pages = []
        self.currentPageIndex = 0
        self.step = .capture
        self.filename = PdfScanUtility.defaultFilename()
        self.savedPdf = nil
        self.savedToPhotosCount = 0
        self.renderCache = [:]
        self.capture.onPageCaptured = { [weak self] result in
            self?.addPage(result)
        }

        // Start from what the user last used, then let a shortcut override it:
        // somebody who scans receipts in black and white every week should not
        // have to say so every week.
        self.captureFilter = Self.storedFilter
        self.capture.isAutoShutterEnabled = Self.storedAutoShutter
        if let request = self.mainCoordinator.consumeScanRequest() {
            if let filter = request.filter { self.captureFilter = filter }
            if let automatic = request.automaticShutter { self.capture.isAutoShutterEnabled = automatic }
        }

        self.analyticsManager.track(event: .reportScreen(.scan))

        #if DEBUG
        // A simulator has no camera, so the review and save screens are
        // otherwise unreachable there. Seed a couple of drawn pages with:
        //   xcrun simctl spawn booted defaults write <bundle-id> debugScanPages -bool YES
        if UserDefaults.standard.bool(forKey: "debugScanPages") {
            self.seedDebugPages()
            // …and debugScanSave=YES goes one step further, to the save sheet.
            if UserDefaults.standard.bool(forKey: "debugScanSave") {
                DispatchQueue.main.async { self.saveSheetShow = true }
            }
        }
        #endif
    }

    #if DEBUG
    /// Two fake captures — a page photographed on a dark surface — so the review
    /// screen has something to show without a camera behind it.
    private func seedDebugPages() {
        let quad = ScanQuad(topLeft: CGPoint(x: 0.12, y: 0.1),
                            topRight: CGPoint(x: 0.88, y: 0.14),
                            bottomRight: CGPoint(x: 0.86, y: 0.9),
                            bottomLeft: CGPoint(x: 0.1, y: 0.86))
        self.pages = (1...2).map { index in
            ScannedPage(original: Self.debugCapture(pageNumber: index),
                        quad: quad,
                        filter: self.captureFilter)
        }
        self.currentPageIndex = 0
        self.step = .review
        self.pages.forEach { self.warmPreview(for: $0) }
    }

    private static func debugCapture(pageNumber: Int) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let paper = CGRect(x: 110, y: 120, width: 700, height: 960)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.12, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.97, alpha: 1).setFill()
            context.fill(paper)

            // The bundled test document, drawn as if photographed: it is a real
            // page — headings, paragraphs, a chart — where drawn grey bars only
            // ever looked like drawn grey bars. The store screenshots are taken
            // from this screen, and a placeholder reads as a placeholder.
            if let document = K.Test.DebugPdfDocument,
               document.pageCount > 0,
               let page = document.page(at: (pageNumber - 1) % document.pageCount) {
                let bounds = page.bounds(for: .mediaBox)
                let scale = min(paper.width / bounds.width, paper.height / bounds.height)
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: paper.minX, y: paper.minY)
                context.cgContext.scaleBy(x: scale, y: scale)
                // PDF pages are drawn bottom-up.
                context.cgContext.translateBy(x: 0, y: bounds.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
                return
            }

            let title = "Debug page \(pageNumber)" as NSString
            title.draw(at: CGPoint(x: 160, y: 190),
                       withAttributes: [.font: UIFont.boldSystemFont(ofSize: 44),
                                        .foregroundColor: UIColor.black])
            for line in 0..<14 {
                UIColor(white: 0.55, alpha: 1).setFill()
                context.fill(CGRect(x: 160, y: 300 + line * 50, width: 600 - (line % 3) * 90, height: 14))
            }
        }
    }
    #endif

    // MARK: Remembered settings

    private static let filterDefaultsKey = "scanFilter"
    private static let autoShutterDefaultsKey = "scanAutomaticShutter"

    private static var storedFilter: ScanFilter {
        guard let raw = UserDefaults.standard.string(forKey: Self.filterDefaultsKey),
              let filter = ScanFilter(rawValue: raw) else {
            return .document
        }
        return filter
    }

    private static var storedAutoShutter: Bool {
        // Absent means "never set", and the automatic shutter is the better
        // default — most people never find the setting either way.
        UserDefaults.standard.object(forKey: Self.autoShutterDefaultsKey) as? Bool ?? true
    }

    private func rememberSettings() {
        UserDefaults.standard.set(self.captureFilter.rawValue, forKey: Self.filterDefaultsKey)
        UserDefaults.standard.set(self.capture.isAutoShutterEnabled, forKey: Self.autoShutterDefaultsKey)
    }

    func onCameraAppear() {
        Task { await self.capture.start() }
    }

    func onCameraDisappear() {
        self.capture.stop()
        self.rememberSettings()
    }

    // MARK: - Pages

    func addPage(_ result: ScanCaptureResult) {
        let page = ScannedPage(original: result.image,
                               quad: result.quad,
                               filter: self.captureFilter,
                               rotation: .none)
        self.pages.append(page)
        self.currentPageIndex = self.pages.count - 1
        self.warmPreview(for: page)
        self.analyticsManager.track(event: .scanPageCaptured(automatic: result.isAutomatic))
    }

    func deletePage(id: UUID) {
        guard let index = self.pages.firstIndex(where: { $0.id == id }) else { return }
        self.pages.remove(at: index)
        self.currentPageIndex = min(self.currentPageIndex, max(self.pages.count - 1, 0))
        if self.pages.isEmpty {
            self.step = .capture
        }
    }

    func movePage(from source: IndexSet, to destination: Int) {
        self.pages.move(fromOffsets: source, toOffset: destination)
    }

    func rotateCurrentPage() {
        self.update(pageAt: self.currentPageIndex) { $0.rotation = $0.rotation.turnedClockwise() }
    }

    /// "3 pages", for the button that leaves the camera — and "1 page" when
    /// there is one, which the count on its own got wrong in every language.
    var pageCountText: String {
        self.pages.count == 1
            ? String(localized: "1 page")
            : String(localized: "\(self.pages.count) pages")
    }

    func setFilter(_ filter: ScanFilter, forPageAt index: Int) {
        self.captureFilter = filter
        self.update(pageAt: index) { $0.filter = filter }
        self.analyticsManager.track(event: .scanFilterApplied(filter: filter, appliedToAll: false))
    }

    /// Applies one filter to the whole stack.
    func setFilterForAllPages(_ filter: ScanFilter) {
        self.captureFilter = filter
        for index in self.pages.indices {
            self.update(pageAt: index) { $0.filter = filter }
        }
        self.analyticsManager.track(event: .scanFilterApplied(filter: filter, appliedToAll: true))
    }

    func setQuad(_ quad: ScanQuad?, forPageAt index: Int) {
        self.update(pageAt: index) { $0.quad = quad?.clamped().normalizedCorners() }
        self.analyticsManager.track(event: .scanCropAdjusted)
    }

    private func update(pageAt index: Int, _ change: (inout ScannedPage) -> Void) {
        guard self.pages.indices.contains(index) else { return }
        var page = self.pages[index]
        change(&page)
        self.pages[index] = page
        self.warmPreview(for: page)
    }

    // MARK: - Rendering

    /// The rendered page, if it is ready. Views ask for it and re-ask when the
    /// cache publishes; a miss kicks off the render and returns nil so the UI
    /// can show the raw capture in the meantime.
    func preview(for page: ScannedPage, maxDimension: CGFloat = K.Misc.ScanPreviewMaxDimension) -> UIImage? {
        let key = self.cacheKey(page: page, maxDimension: maxDimension)
        if let cached = self.renderCache[key] { return cached }
        self.warmPreview(for: page, maxDimension: maxDimension)
        return nil
    }

    func warmPreview(for page: ScannedPage, maxDimension: CGFloat = K.Misc.ScanPreviewMaxDimension) {
        let key = self.cacheKey(page: page, maxDimension: maxDimension)
        guard self.renderCache[key] == nil, !self.renderTasks.contains(key) else { return }
        self.renderTasks.insert(key)

        Task.detached(priority: .userInitiated) { [weak self] in
            let image = ScanImageProcessor.render(page, maxDimension: maxDimension)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.renderTasks.remove(key)
                guard let image else { return }
                // A long session should not hold every render of every page.
                if self.renderCache.count > 60 { self.renderCache.removeAll() }
                self.renderCache[key] = image
                // The cache is not `@Published` — it is a dictionary read through
                // `preview(for:)`, and publishing it would redraw on every key.
                // But nothing else changes when a render lands, so without this
                // the screen keeps whatever it drew while waiting: the unfiltered
                // capture. That is what "the filter does nothing the first time"
                // was — the filter had been applied, to an image nobody asked for
                // again.
                self.objectWillChange.send()
            }
        }
    }

    private func cacheKey(page: ScannedPage, maxDimension: CGFloat) -> String {
        "\(page.renderKey)-\(Int(maxDimension))"
    }

    // MARK: - Finishing

    /// Leaves the camera for the review screen — or, with nothing taken yet,
    /// does nothing.
    func review() {
        guard !self.pages.isEmpty else { return }
        self.currentPageIndex = min(self.currentPageIndex, self.pages.count - 1)
        self.step = .review
    }

    func resumeCapture() {
        self.step = .capture
    }

    func trackReviewScreen() {
        self.analyticsManager.track(event: .reportScreen(.scanReview))
    }

    /// The last capture, thrown away — the "Retake" of the review screen.
    func retakeCurrentPage() {
        guard let page = self.currentPage else { return }
        self.analyticsManager.track(event: .scanPageRetaken)
        self.deletePage(id: page.id)
        self.step = .capture
    }

    func finish() {
        guard self.canFinish else { return }
        switch self.mode {
        case .handOff:
            self.onHandOff?(self.pages)
        case .newDocument:
            self.saveSheetShow = true
        }
    }

    // MARK: Save as PDF

    func saveAsPdf() {
        guard self.canFinish else { return }
        let name = self.trimmedFilename
        let pages = self.pages

        self.analyticsManager.track(event: .scanSaved(format: .pdf, pageCount: pages.count))
        PdfScanUtility.convertScan(pages: pages,
                                   filename: name,
                                   asyncOperation: self.asyncSubject(\.asyncPdf))
    }

    /// Called by the flow when `asyncPdf` produces the document, so the archive
    /// write stays off the conversion's progress path.
    func store(pdf: Pdf) {
        do {
            let saved = try self.repository.savePdf(pdf: pdf)
            self.savedPdf = saved
            self.saveSheetShow = false
            self.onSaved?(saved)
        } catch {
            self.asyncSave = .error(.unknownError)
        }
    }

    // MARK: Save as images

    func saveAsImages() {
        guard self.canFinish else { return }
        let pages = self.pages
        let progress = Progress(totalUnitCount: Int64(pages.count))
        self.asyncSave = .loading(progress)

        Task {
            let images: [UIImage] = await Task.detached(priority: .userInitiated) {
                pages.compactMap { ScanImageProcessor.render($0, maxDimension: K.Misc.ScanPageMaxDimension) }
            }.value

            do {
                try await PhotoLibrarySaver.save(images: images)
                self.analyticsManager.track(event: .scanSaved(format: .image, pageCount: images.count))
                self.asyncSave = .idle
                self.savedToPhotosCount = images.count
                self.saveSheetShow = false
                self.savedToPhotosAlertShow = true
            } catch PhotoLibrarySaveError.notAuthorized {
                self.asyncSave = .idle
                self.photosPermissionDeniedShow = true
            } catch {
                self.asyncSave = .error(.unknownError)
            }
        }
    }

    // MARK: - Helpers

    /// Filenames come from a text field, so they can arrive empty or padded.
    var trimmedFilename: String {
        let trimmed = self.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? PdfScanUtility.defaultFilename() : trimmed
    }
}
