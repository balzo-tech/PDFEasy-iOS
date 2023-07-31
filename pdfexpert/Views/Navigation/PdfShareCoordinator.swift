//
//  PdfShareCoordinator.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/07/23.
//

import Foundation
import Factory

extension Container {
    var pdfShareCoordinator: ParameterFactory<PdfShareCoordinator.Params, PdfShareCoordinator> {
        self { PdfShareCoordinator($0) }
    }
}

class PdfShareCoordinator: ObservableObject {
    
    struct Params {
        let applyPostProcess: Bool
    }
    
    @Published var monetizationShow: Bool = false
    @Published var pdfToBeShared: PdfEditable?
    
    let applyPostProcess: Bool
    
    init(_ params: Params) {
        self.applyPostProcess = params.applyPostProcess
    }
    
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store
    
    private var pdfWantToBeShared: PdfEditable? = nil
    
    func share(pdf: PdfEditable) {
        self.analyticsManager.track(event: .pdfShared(marginsOption: nil, compressionValue: nil))
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
