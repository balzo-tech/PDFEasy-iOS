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
    
    @Injected(\.repository) private var repository
    @Injected(\.store) private var store
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.mainCoordinator) private var mainCoordinator
    @Injected(\.pdfShareCoordinator) var pdfShareCoordinator
    
    let syncMonitor = SyncMonitor.shared
    
    private var cancelBag = Set<AnyCancellable>()
    
    init() {
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
        
        // Refresh the pdf list every time the pdf edit flow is dismissed
        self.mainCoordinator.$pdfEditFlowData.filter { $0 == nil }.sink { data in
            self.refresh()
        }.store(in: &self.cancelBag)
    }
    
    func editItem(item: Pdf) {
        self.analyticsManager.track(event: .existingPdfOpened)
        self.mainCoordinator.showPdfEditFlow(pdf: item, isNewPdf: false)
    }
    
    func shareItem(item: Pdf) {
        self.pdfShareCoordinator.share(pdf: item, applyPostProcess: true, onComplete: { [weak self] in
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
        #endif
    }

    #if DEBUG
    /// Fills an empty archive with copies of the bundled test document, so the
    /// Files layouts can be exercised on a simulator where importing is not
    /// possible. Enable with:
    ///   xcrun simctl spawn booted defaults write <bundle-id> debugSeedArchive -bool YES
    private func seedDebugArchiveIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "debugSeedArchive"),
              (try? self.repository.getDoPdfExist()) == false else { return }
        let names = ["Rental agreement", "Invoice 2026-07", "Scanned receipt", "Passport scan", "Meeting notes"]
        for name in names {
            guard var pdf = K.Test.DebugPdf else { return }
            pdf.updateFilename("\(name).pdf")
            _ = try? self.repository.savePdf(pdf: pdf)
        }
    }
    #endif
    
    func refresh() {
        do {
            let items = try self.repository.loadPdfs()
            self.asyncItems = AsyncOperation(status: .data(items))
            self.updateWidgetSnapshot(items: items)
        } catch {
            debugPrint(for: self, message: "Refresh failed. Error: \(error)")
            self.asyncItems = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
        }
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
            let identifier = pdf.storeId?.uriRepresentation().absoluteString ?? pdf.filename
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

    /// Filters by filename and indexed page text (case- and diacritic-insensitive).
    /// Returns all items when the query is empty. PDFs saved before text indexing
    /// (or never re-saved/OCR'd) have no `searchableText`, so they match by filename
    /// only.
    func filteredItems(_ items: [Pdf]) -> [Pdf] {
        let query = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { pdf in
            Self.matches(pdf.filename, query) || Self.matches(pdf.searchableText, query)
        }
    }

    private static func matches(_ text: String?, _ query: String) -> Bool {
        guard let text else { return false }
        return text.range(of: query,
                          options: [.caseInsensitive, .diacriticInsensitive],
                          locale: .current) != nil
    }
}
