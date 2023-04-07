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
    
    @Published var items: AsyncOperation<[Pdf], SharedLocalizedError> = AsyncOperation(status: .empty)
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
    
    func refresh() {
        do {
            let items = try self.repository.loadPdfs()
            self.items = AsyncOperation(status: .data(items))
        } catch {
            debugPrint(for: self, message: "Error: \(error)")
            self.items = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
        }
    }
    
    func updateView(){
        self.objectWillChange.send()
    }
}
