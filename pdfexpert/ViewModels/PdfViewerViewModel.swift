//
//  PdfViewerViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import Foundation
import Factory

extension Container {
    var pdfViewerViewModel: ParameterFactory<PdfViewerViewModel.InputParameter, PdfViewerViewModel> {
        self { PdfViewerViewModel(inputParameter: $0) }.shared
    }
}

class PdfViewerViewModel: ObservableObject {
    
    struct InputParameter {
        let pdf: Pdf
        let marginsOption: MarginsOption?
        let compression: CGFloat?
    }
    
    @Published var pdf: Pdf
    @Published var pdfToBeShared: Pdf?
    @Published var monetizationShow: Bool = false
    @Published var pdfSaveError: PdfEditSaveError? = nil
    
    @Injected(\.store) private var store
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.repository) private var repository
    
    private let marginsOption: MarginsOption?
    private let compression: CGFloat?
    
    init(inputParameter: InputParameter) {
        self.pdf = inputParameter.pdf
        self.marginsOption = inputParameter.marginsOption
        self.compression = inputParameter.compression
    }
    
    func share() {
        if self.store.isPremium.value {
            self.pdfToBeShared = self.pdf
            self.analyticsManager.track(event: .pdfShared(marginsOption: self.marginsOption, compressionValue: self.compression))
        } else {
            self.monetizationShow = true
        }
    }
    
    func setPassword(_ password: String) {
        self.internalSetPassword(password)
        debugPrint(for: self, message: "New password: \(password)")
        self.analyticsManager.track(event: .passwordAdded)
    }
    
    func removePassword() {
        self.internalSetPassword(nil)
        debugPrint(for: self, message: "Password removed")
        self.analyticsManager.track(event: .passwordRemoved)
    }
    
    private func internalSetPassword(_ password: String?) {
        do {
            self.pdf.password = password
            try self.repository.saveChanges()
        } catch {
            debugPrint(for: self, message: "Pdf save failed with error: \(error)")
            self.pdfSaveError = .saveFailed
        }
    }
}
