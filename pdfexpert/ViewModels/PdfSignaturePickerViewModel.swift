//
//  PdfSignaturePickerViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/08/23.
//

import Foundation
import Factory

extension Container {
    var pdfSignaturePickerViewModel: ParameterFactory<PdfSignaturePickerViewModel.Params, PdfSignaturePickerViewModel> {
        self { PdfSignaturePickerViewModel(params: $0) }
    }
}

class PdfSignaturePickerViewModel: ObservableObject {
    
    typealias ConfirmationCallback = ((Signature) -> ())
    typealias CancelCallback = (() -> ())
    typealias CreateNewSignatureCallback = (() -> ())
    
    struct Params {
        let confirmationCallback: ConfirmationCallback
        let cancelCallback: CancelCallback
        let createNewSignatureCallback: CreateNewSignatureCallback
    }
    
    @Published var asyncItems: AsyncOperation<[Signature], SharedLocalizedError> = AsyncOperation(status: .empty)
    @Published var asyncItemDelete: AsyncOperation<(), SharedLocalizedError> = AsyncOperation(status: .empty)
    @Published var isLoading: Bool = false
    
    @Injected(\.repository) var repository
    @Injected(\.analyticsManager) private var analyticsManager
    
    private let onConfirm: ConfirmationCallback
    private let onCancel: CancelCallback
    private let onCreateNewSignature: CreateNewSignatureCallback
    
    init(params: Params) {
        self.onConfirm = params.confirmationCallback
        self.onCancel = params.cancelCallback
        self.onCreateNewSignature = params.createNewSignatureCallback
    }
    
    func pick(item: Signature) {
        self.onConfirm(item)
    }
    
    func delete(item: Signature) {
        self.asyncItemDelete = AsyncOperation(status: .empty)
        do {
            try self.repository.delete(signature: item)
            self.asyncItemDelete = AsyncOperation(status: .empty)
        } catch {
            debugPrint(for: self, message: "Deletion failed. Error: \(error)")
            self.asyncItemDelete = AsyncOperation(status: .error(.unknownError))
        }
        self.refresh()
    }
    
    func delete(indexSet: IndexSet) {
        guard let allSignatures = asyncItems.data else {
            return
        }
        
        let signatures = indexSet.filteredIndexSet { $0 < allSignatures.count }.map { allSignatures[$0] }
        
        self.asyncItemDelete = AsyncOperation(status: .empty)
        do {
            try self.repository.delete(signatures: signatures)
            self.asyncItemDelete = AsyncOperation(status: .empty)
        } catch {
            debugPrint(for: self, message: "Deletion failed. Error: \(error)")
            self.asyncItemDelete = AsyncOperation(status: .error(.unknownError))
        }
        self.refresh()
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.signaturePicker))
        self.refresh()
    }
    
    func cancel() {
        self.onCancel()
    }
    
    func createNewSignature() {
        self.onCreateNewSignature()
    }
    
    func refresh() {
        do {
            let items = try self.repository.loadSignatures()
            self.asyncItems = AsyncOperation(status: .data(items))
        } catch {
            debugPrint(for: self, message: "Refresh failed. Error: \(error)")
            self.asyncItems = AsyncOperation(status: .error(SharedLocalizedError.unknownError))
        }
    }
}
