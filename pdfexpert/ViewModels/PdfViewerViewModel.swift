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
        self { PdfViewerViewModel(inputParameter: $0) }
    }
}

class PdfViewerViewModel: ObservableObject {
    
    struct InputParameter {
        let pdf: PdfEditable
        let marginsOption: MarginsOption?
        let compression: CGFloat?
    }
    
    @Published var pdf: PdfEditable
    @Published var pdfToBeShared: PdfEditable?
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
            self.pdf.updatePassword(password)
            // Setting the password doesn't notify the state change to SwiftUI,
            // so we must force a refresh. Not pretty, but better than uglier things such as adding more states.
            self.objectWillChange.send()
            self.pdf = try self.repository.savePdf(pdfEditable: self.pdf)
        } catch {
            debugPrint(for: self, message: "Pdf save failed with error: \(error)")
            self.pdfSaveError = .saveFailed
        }
    }
}
