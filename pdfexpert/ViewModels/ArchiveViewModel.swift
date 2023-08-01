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
    
    @Injected(\.repository) private var repository
    @Injected(\.store) private var store
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.mainCoordinator) private var mainCoordinator
    
    let pdfShareCoordinator = Container.shared.pdfShareCoordinator(PdfShareCoordinator.Params(applyPostProcess: true))
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
        self.pdfShareCoordinator.share(pdf: item)
    }
    
    func delete(item: Pdf) {
        self.asyncItemDelete = AsyncOperation(status: .empty)
        do {
            try self.repository.delete(pdf: item)
            self.asyncItemDelete = AsyncOperation(status: .empty)
            self.analyticsManager.track(event: .existingPdfRemoved)
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
}
