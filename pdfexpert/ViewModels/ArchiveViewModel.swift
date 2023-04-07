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
        self { ArchiveViewModel() }.shared
    }
}

class ArchiveViewModel: ObservableObject {
    
    @Published var asyncItems: AsyncOperation<[Pdf], SharedLocalizedError> = AsyncOperation(status: .empty)
    @Published var asyncItemDelete: AsyncOperation<(), SharedLocalizedError> = AsyncOperation(status: .empty)
    @Published var pdfToBeShared: Pdf?
    @Published var isLoading: Bool = false
    
    @Injected(\.repository) private var repository
    
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
    }
    
    func shareItem(item: Pdf) {
        self.pdfToBeShared = item
    }
    
    func delete(item: Pdf) {
        self.asyncItemDelete = AsyncOperation(status: .empty)
        self.repository.delete(pdf: item)
        do {
            try self.repository.saveChanges()
            self.asyncItemDelete = AsyncOperation(status: .empty)
        } catch {
            debugPrint(for: self, message: "Deletion failed. Error: \(error)")
            self.asyncItemDelete = AsyncOperation(status: .error(.unknownError))
        }
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
}
