//
//  ArchiveViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import Foundation
import Factory
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
        self.refresh()
    }
    
    func refresh() {
        do {
            let items = try self.repository.loadPdfs()
            self.asyncItems = AsyncOperation(status: .data(items))
        } catch {
            debugPrint(for: self, message: "Refresh failed. Error: \(error)")
            self.asyncItems = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
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
