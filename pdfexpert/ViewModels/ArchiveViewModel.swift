//
//  ArchiveViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import Foundation
import Factory
import UIKit
import WidgetKit
import CoreData
import Combine
import CloudKitSyncMonitor

extension Container {
    var archiveViewModel: Factory<ArchiveViewModel> {
        self { ArchiveViewModel() }
    }
}

class ArchiveViewModel: ObservableObject {
    
    @Published var asyncItems: AsyncOperation<[Pdf], SharedLocalizedError> = AsyncOperation(status: .empty)
    @Published var asyncItemDelete: AsyncOperation<(), SharedLocalizedError> = AsyncOperation(status: .empty)
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""

    // Filing. The folder and tag lists are kept alongside the documents because
    // every screen that shows a document also has to be able to file it.
    @Published var folders: [Folder] = []
    @Published var tags: [Tag] = []
    @Published var folderFilter: FolderFilter = .all
    @Published var selectedTagIds: Set<String> = []
    @Published var asyncFiling: AsyncOperation<(), SharedLocalizedError> = AsyncOperation(status: .empty)
    
    @Injected(\.repository) private var repository
    @Injected(\.store) private var store
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.mainCoordinator) private var mainCoordinator
    @Injected(\.pdfShareCoordinator) var pdfShareCoordinator
    
    private var cancelBag = Set<AnyCancellable>()

    init() {
        // Reaching for the monitor builds a CloudKit container there and then,
        // and a process without the iCloud entitlement — a locally signed
        // development build — is answered with an exception rather than an
        // error. There is no import to watch in that case anyway.
        if !PersistenceController.isCloudKitDisabledForDevelopment {
            self.observeCloudKitImport()
        }

        // Refresh the pdf list every time the pdf edit flow is dismissed
        self.mainCoordinator.$pdfEditFlowData.filter { $0 == nil }.sink { data in
            self.refresh()
        }.store(in: &self.cancelBag)
    }

    private func observeCloudKitImport() {
        SyncMonitor.shared.$importState.sink { [weak self] importState in
            switch importState {
            case .inProgress:
                self?.isLoading = true
            case .succeeded:
                self?.refresh()
                self?.isLoading = false
            case .failed:
                self?.refresh()
                self?.isLoading = false
            case .notStarted:
                self?.isLoading = false
            }
            self?.updateView()
        }.store(in: &self.cancelBag)
    }
    
    func editItem(item: Pdf) {
        self.analyticsManager.track(event: .existingPdfOpened)
        self.mainCoordinator.showPdfEditFlow(pdf: item, isNewPdf: false)
    }
    
    func shareItem(item: Pdf) {
        self.pdfShareCoordinator.share(pdf: item, onComplete: { [weak self] in
            self?.mainCoordinator.startReview()
        })
    }

    /// Persists metadata edits made from the archive's "Document info" sheet, then
    /// refreshes the list so the row reflects the saved document.
    func updateItem(item: Pdf) {
        try? self.repository.savePdf(pdf: item)
        self.refresh()
    }
    
    func delete(item: Pdf) {
        self.asyncItemDelete = AsyncOperation(status: .empty)
        do {
            try self.repository.delete(pdf: item)
            self.asyncItemDelete = AsyncOperation(status: .empty)
        } catch {
            debugPrint(for: self, message: "Deletion failed. Error: \(error)")
            self.asyncItemDelete = AsyncOperation(status: .error(.unknownError))
        }
        self.refresh()
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.files))
        #if DEBUG
        self.seedDebugArchiveIfNeeded()
        self.seedDebugSignatureIfNeeded()
        #endif
        self.refresh()
        #if DEBUG
        // debugOpenEditor=YES opens the first document straight away, so the
        // editor can be inspected on a simulator without tapping.
        if UserDefaults.standard.bool(forKey: "debugOpenEditor"),
           case .data(let items) = self.asyncItems.status,
           let first = items.first {
            DispatchQueue.main.async { self.editItem(item: first) }
        }
        // debugSelectDocument=YES previews the first document in the iPad
        // detail column, which cannot otherwise be reached on a simulator.
        if UserDefaults.standard.bool(forKey: "debugSelectDocument"),
           case .data(let items) = self.asyncItems.status,
           let first = items.first {
            DispatchQueue.main.async { self.mainCoordinator.selectedDocumentId = first.documentId }
        }
        #endif
    }

    #if DEBUG
    /// Fills an empty archive with copies of the bundled test document, so the
    /// Files layouts can be exercised on a simulator where importing is not
    /// possible. Enable with:
    ///   xcrun simctl spawn booted defaults write <bundle-id> debugSeedArchive -bool YES
    private func seedDebugArchiveIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "debugSeedArchive") else { return }
        // debugResetArchive=YES empties it first, so the seed lands whatever the
        // last run left behind. A UI test bundle installs the app fresh but keeps
        // the container: the scanner tests save documents, and the archive tests
        // that ran after them found a non-empty archive, skipped the seed and
        // failed looking for folders nobody had made. A test that only passes
        // when it runs first is not a test.
        if UserDefaults.standard.bool(forKey: "debugResetArchive") {
            for pdf in (try? self.repository.loadPdfs()) ?? [] {
                try? self.repository.delete(pdf: pdf)
            }
            for folder in (try? self.repository.loadFolders()) ?? [] {
                try? self.repository.delete(folder: folder)
            }
            for tag in (try? self.repository.loadTags()) ?? [] {
                try? self.repository.delete(tag: tag)
            }
        }
        guard (try? self.repository.getDoPdfExist()) == false else { return }
        // The lease goes last, so it lands at the top of the archive: it is the
        // one the store screenshots open, and the only one of the five that is
        // not Lorem ipsum. The other four are only ever a list behind it.
        var toSave: [(name: String, pdf: Pdf?)] = ["Invoice 2026-07", "Scanned receipt",
                                                   "Passport scan", "Meeting notes"]
            .map { ($0, K.Test.DebugPdf) }
        toSave.append((K.Test.DebugContractFilename, K.Test.DebugContractPdf))

        var saved: [Pdf] = []
        for entry in toSave {
            guard var pdf = entry.pdf else { return }
            pdf.updateFilename("\(entry.name).pdf")
            if let stored = try? self.repository.savePdf(pdf: pdf) {
                saved.append(stored)
            }
        }

        // Some filing too, so the filter bar and the tag dots have something to
        // show on a simulator where nothing can be tapped.
        let work = try? self.repository.save(folder: Folder(name: "Work", color: .blue))
        let home = try? self.repository.save(folder: Folder(name: "Home", color: .green))
        let urgent = try? self.repository.save(tag: Tag(name: "Urgent", color: .red))
        let year = try? self.repository.save(tag: Tag(name: "2026", color: .purple))

        for (index, pdf) in saved.enumerated() {
            let folder = index % 3 == 2 ? nil : (index.isMultiple(of: 2) ? work : home)
            let pdf = (try? self.repository.setFolder(folder, for: pdf)) ?? pdf
            let tags = [index.isMultiple(of: 2) ? urgent : nil, index % 3 == 0 ? year : nil].compactMap { $0 }
            _ = try? self.repository.setTags(tags, for: pdf)
        }
    }

    /// Puts one signature in the store before the first screen appears, so the
    /// App Store shots can show a signature that looks written.
    ///
    /// The alternative was drawing one in the app from the test, and a
    /// synthesized drag draws a straight segment: eight of them in a row read as
    /// a scribble across the contract, wherever they land. With a signature
    /// already saved the app offers it instead of an empty canvas — which is
    /// also what the slide claims, that you draw it once and reuse it.
    ///
    /// The name is the tenant of the lease being photographed, so it comes in on
    /// the command line rather than being written here:
    ///   xcrun simctl launch booted <bundle-id> -debugSeedSignature "Daniel Markwart"
    private func seedDebugSignatureIfNeeded() {
        guard let name = UserDefaults.standard.string(forKey: "debugSeedSignature"),
              false == name.isEmpty else { return }

        // The container outlives a run, and a signature is not a document:
        // `debugResetArchive` empties the archive and leaves the signatures
        // alone. Without this the German shot would be signed by whoever the
        // run before it photographed — an Italian name on a Berlin lease.
        if UserDefaults.standard.bool(forKey: "debugResetArchive") {
            try? self.repository.delete(signatures: (try? self.repository.loadSignatures()) ?? [])
        }
        guard (try? self.repository.getDoSignatureExist()) == false else { return }

        // Snell Roundhand ships with the system, so the ink is drawn here rather
        // than carried as a PNG that would have to live in the bundle, be added
        // to the target by hand, and be redrawn for every language.
        let font = UIFont(name: "SnellRoundhand-Bold", size: 160) ?? .italicSystemFont(ofSize: 160)
        let text = NSAttributedString(string: name,
                                      attributes: [.font: font, .foregroundColor: UIColor.black])
        let ink = text.size()
        // A new signature is laid across 70% of the page width whatever it is
        // — `startingSignatureWidthOverPdfViewWidth` in PdfSignatureViewModel —
        // so a name that fills its image comes out as wide as the page and reads
        // as a stamp. The ink is drawn small inside a wide transparent image
        // instead: most of what gets scaled to that 70% is margin, and what
        // shows is the size a person would sign.
        let canvas = CGSize(width: ink.width * 2.2, height: ink.height * 1.5)
        let format = UIGraphicsImageRendererFormat.default()
        // The page has to show through around the ink: an opaque signature lands
        // on the contract as a white box with a name in it.
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            text.draw(at: CGPoint(x: (canvas.width - ink.width) / 2,
                                  y: (canvas.height - ink.height) / 2))
        }
        _ = try? self.repository.saveSignature(signature: Signature(image: image))
    }
    #endif
    
    func refresh() {
        do {
            let items = try self.repository.loadPdfs()
            self.asyncItems = AsyncOperation(status: .data(items))
            self.updateWidgetSnapshot(items: items)
            self.refreshFiling()
        } catch {
            debugPrint(for: self, message: "Refresh failed. Error: \(error)")
            self.asyncItems = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
        }
    }

    /// Reloads folders and tags, and drops any filter pointing at something that
    /// no longer exists (deleted here, or on another device through iCloud).
    private func refreshFiling() {
        self.folders = (try? self.repository.loadFolders()) ?? []
        self.tags = (try? self.repository.loadTags()) ?? []

        if case .folder(let id) = self.folderFilter, !self.folders.contains(where: { $0.id == id }) {
            self.folderFilter = .all
        }
        let existingTagIds = Set(self.tags.map(\.id))
        self.selectedTagIds.formIntersection(existingTagIds)
    }

    /// Keeps the widget's copy of the recent documents in step with the archive.
    /// Thumbnails are generated here (the grid needs them anyway) and written to
    /// the shared container off the main thread.
    private func updateWidgetSnapshot(items: [Pdf]) {
        let recents = items
            .sorted { $0.creationDate > $1.creationDate }
            .prefix(SharedDocumentStore.maxDocuments)

        var documents: [SharedDocument] = []
        var thumbnails: [String: UIImage] = [:]

        for (index, pdf) in recents.enumerated() {
            let identifier = pdf.documentId
            var thumbnailName: String? = nil
            if let thumbnail = pdf.thumbnail {
                // A widget never shows these bigger than a few hundred points.
                let longestSide = max(thumbnail.size.width, thumbnail.size.height)
                let scale = longestSide > 320 ? 320 / longestSide : 1
                let name = "\(index).png"
                thumbnails[name] = scale < 1 ? (thumbnail.scaledImage(scaleFactor: scale) ?? thumbnail) : thumbnail
                thumbnailName = name
            }
            documents.append(SharedDocument(id: identifier,
                                            filename: pdf.filename,
                                            pageCount: pdf.pageCount,
                                            creationDate: pdf.creationDate,
                                            thumbnailName: thumbnailName))
        }

        let snapshot = documents
        let images = thumbnails
        DispatchQueue.global(qos: .utility).async {
            SharedDocumentStore.save(snapshot, thumbnails: images)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func updateView(){
        self.objectWillChange.send()
    }

    // MARK: - Filtering

    /// The loaded archive, empty while it is still loading or on error.
    var documents: [Pdf] {
        self.asyncItems.data ?? []
    }

    /// First colour not already taken by another folder, so a fresh archive ends
    /// up with distinguishable chips without the user picking anything.
    var suggestedFolderColor: ArchiveColor {
        Self.suggestedColor(avoiding: self.folders.map(\.color))
    }

    var suggestedTagColor: ArchiveColor {
        Self.suggestedColor(avoiding: self.tags.map(\.color))
    }

    private static func suggestedColor(avoiding used: [ArchiveColor]) -> ArchiveColor {
        ArchiveColor.allCases.first { !used.contains($0) } ?? .blue
    }

    var filter: ArchiveFilter {
        ArchiveFilter(searchText: self.searchText,
                      folder: self.folderFilter,
                      tagIds: self.selectedTagIds)
    }

    /// Filters by folder, tags and text (filename, indexed page text, folder and
    /// tag names — case- and diacritic-insensitive). PDFs saved before text
    /// indexing (or never re-saved/OCR'd) have no `searchableText`, so they match
    /// by filename only.
    func filteredItems(_ items: [Pdf]) -> [Pdf] {
        self.filter.apply(to: items)
    }

    func clearFilters() {
        self.folderFilter = .all
        self.selectedTagIds = []
    }

    func toggleTagFilter(_ tag: Tag) {
        if self.selectedTagIds.contains(tag.id) {
            self.selectedTagIds.remove(tag.id)
        } else {
            self.selectedTagIds.insert(tag.id)
        }
    }

    // MARK: - Folders and tags

    /// Creates a folder, or returns the existing one when the name is already
    /// taken: two folders called "Invoices" would just split the same pile.
    @discardableResult
    func createFolder(name: String, color: ArchiveColor) -> Folder? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = self.folders.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        return self.persist { try self.repository.save(folder: Folder(name: name, color: color)) }
    }

    @discardableResult
    func updateFolder(_ folder: Folder) -> Folder? {
        self.persist { try self.repository.save(folder: folder) }
    }

    /// The documents inside are not deleted — they go back to being unfiled.
    func deleteFolder(_ folder: Folder) {
        self.persist { try self.repository.delete(folder: folder) }
    }

    @discardableResult
    func createTag(name: String, color: ArchiveColor) -> Tag? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = self.tags.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        return self.persist { try self.repository.save(tag: Tag(name: name, color: color)) }
    }

    @discardableResult
    func updateTag(_ tag: Tag) -> Tag? {
        self.persist { try self.repository.save(tag: tag) }
    }

    func deleteTag(_ tag: Tag) {
        self.persist { try self.repository.delete(tag: tag) }
    }

    // MARK: - Filing a document

    func setFolder(_ folder: Folder?, for pdf: Pdf) {
        self.persist { try self.repository.setFolder(folder, for: pdf) }
    }

    func toggleTag(_ tag: Tag, for pdf: Pdf) {
        var tags = pdf.tags
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags.remove(at: index)
        } else {
            tags.append(tag)
        }
        self.persist { try self.repository.setTags(tags, for: pdf) }
    }

    /// Runs a store mutation, then reloads: every filing change is small and the
    /// archive is already fully in memory, so a refresh is cheaper than trying to
    /// patch the published list in place.
    @discardableResult
    private func persist<T>(_ operation: () throws -> T) -> T? {
        do {
            let result = try operation()
            self.refresh()
            return result
        } catch {
            debugPrint(for: self, message: "Filing operation failed. Error: \(error)")
            self.asyncFiling = AsyncOperation(status: .error(.unknownError))
            return nil
        }
    }
}
