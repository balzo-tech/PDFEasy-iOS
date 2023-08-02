//
//  PdfShareCoordinator.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/07/23.
//

import Foundation
import Factory

extension Container {
    var pdfShareCoordinator: Factory<PdfShareCoordinator> {
        self { PdfShareCoordinator() }
    }
}

class PdfShareCoordinator: ObservableObject {
    
    @Published var monetizationShow: Bool = false
    @Published var pdfToBeShared: Pdf?
    
    var applyPostProcess: Bool = false
    
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    
    private var pdfWantToBeShared: Pdf? = nil
    
    func share(pdf: Pdf, applyPostProcess: Bool) {
        self.analyticsManager.track(event: .pdfShared)
        self.applyPostProcess = applyPostProcess
        if self.store.isPremium.value {
            self.pdfToBeShared = pdf
        } else {
            self.monetizationShow = true
            // Store pdf to share it after a successful subscription
            self.pdfWantToBeShared = pdf
        }
    }
    
    func onMonetizationClose() {
        if self.store.isPremium.value {
            // Share previously stored pdf, if existing.
            self.pdfToBeShared = self.pdfWantToBeShared
            self.pdfWantToBeShared = nil
        }
    }
}
