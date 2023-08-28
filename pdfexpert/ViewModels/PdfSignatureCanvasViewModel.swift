//
//  PdfSignatureCanvasViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/05/23.
//

import Foundation
import Factory
import UIKit
import PencilKit

extension Container {
    var pdfSignatureCanvasViewModel: ParameterFactory<PdfSignatureCanvasViewModel.ConfirmationCallback, PdfSignatureCanvasViewModel> {
        self { PdfSignatureCanvasViewModel(onConfirm: $0) }
    }
}

class PdfSignatureCanvasViewModel: ObservableObject {
    
    typealias ConfirmationCallback = ((Signature) -> ())
    
    @Published var canvasView = PKCanvasView()
    @Published var shouldSaveSignature: Bool = false
    @Published var pdfSaveError: SharedUnderlyingError? = nil
    
    @Injected(\.repository) private var repository
    @Injected(\.analyticsManager) private var analyticsManager
    
    private var confirmAllowed: Bool { self.canvasView.drawing.strokes.count > 0 }
    
    private let onConfirm: ConfirmationCallback
    
    init(onConfirm: @escaping ConfirmationCallback) {
        self.onConfirm = onConfirm
    }
    
    func onClearButtonPressed() {
        self.canvasView.drawing = PKDrawing()
    }
    
    func toggleShouldSave() {
        self.shouldSaveSignature = !self.shouldSaveSignature
    }
    
    func onConfirmButtonPressed() {
        var signature = Signature(drawing: self.canvasView.drawing)
        if self.shouldSaveSignature {
            do {
                signature = try self.repository.saveSignature(signature: signature)
            } catch {
                self.pdfSaveError = .convertError(fromError: error)
            }
        }
        self.analyticsManager.track(event: .signatureCreated)
        self.onConfirm(signature)
    }
}
