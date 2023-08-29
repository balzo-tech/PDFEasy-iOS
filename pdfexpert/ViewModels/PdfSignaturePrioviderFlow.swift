//
//  PdfSignaturePrioviderFlow.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/08/23.
//

import Foundation
import Factory
import UIKit

extension Container {
    var pdfSignaturePrioviderFlow: Factory<PdfSignaturePrioviderFlow> {
        self { PdfSignaturePrioviderFlow() }
    }
}

class PdfSignaturePrioviderFlow: ObservableObject {
    
    typealias SignatureSelectedCallback = ((UIImage) -> ())
    
    @Published var showSignatureCreation: Bool = false
    @Published var showSignaturePicker: Bool = false
    
    @Injected(\.repository) private var repository
    
    private var onSignatureSelected: SignatureSelectedCallback?
    
    func startFlow(onSignatureSelected: @escaping SignatureSelectedCallback) {
        self.onSignatureSelected = onSignatureSelected
        if (try? self.repository.getDoSignatureExist()) ?? false {
            self.showSignaturePicker = true
        } else {
            self.showSignatureCreation = true
        }
    }
    
    func onSignatureSelected(signature: Signature) {
        self.showSignatureCreation = false
        self.showSignaturePicker = false
        self.onSignatureSelected?(signature.image)
    }
    
    @MainActor
    func onCreateNewSignature() {
        self.showSignaturePicker = false
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.showSignatureCreation = true
        }
    }
}
