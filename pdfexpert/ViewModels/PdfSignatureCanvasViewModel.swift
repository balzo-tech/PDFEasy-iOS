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
    var pdfSignatureCanvasViewModel: ParameterFactory<ConfirmationCallback, PdfSignatureCanvasViewModel> {
        self { PdfSignatureCanvasViewModel(onConfirm: $0) }
    }
}

typealias ConfirmationCallback = ((UIImage) -> ())

class PdfSignatureCanvasViewModel: ObservableObject {
    
    typealias ConfirmationCallback = ((UIImage) -> ())
    
    @Published var canvasView = PKCanvasView()
    
    @Injected(\.cacheManager) var cacheManager
    @Injected(\.analyticsManager) private var analyticsManager
    
    private var confirmAllowed: Bool { self.canvasView.drawing.strokes.count > 0 }
    
    private let onConfirm: ConfirmationCallback
    
    init(onConfirm: @escaping ConfirmationCallback) {
        self.onConfirm = onConfirm
        if let signatureData = self.cacheManager.signatureData, let drawing = try? PKDrawing(data: signatureData) {
            self.canvasView.drawing = drawing
        }
    }
    
    func onClearButtonPressed() {
        self.canvasView.drawing = PKDrawing()
    }
    
    func onConfirmButtonPressed() {
        self.cacheManager.signatureData = self.canvasView.drawing.dataRepresentation()
        self.onConfirm(self.canvasView.drawing.image(from: self.canvasView.bounds, scale: 3.0, userInterfaceStyle: .light))
    }
}
