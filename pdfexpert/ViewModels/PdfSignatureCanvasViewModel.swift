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

enum SignatureSource: CaseIterable, Hashable {
    case drawing
    case image
    case camera
}

class PdfSignatureCanvasViewModel: NSObject, ObservableObject {
    
    typealias ConfirmationCallback = ((Signature) -> ())
    
    @Published var canvasView = PKCanvasView()
    @Published var signatureGalleryImage: UIImage? = nil
    @Published var signatureCameraImage: UIImage? = nil
    @Published var shouldSaveSignature: Bool = false
    @Published var pdfSaveError: SharedUnderlyingError? = nil
    @Published var source: SignatureSource = .drawing {
        didSet {
            self.onSourceChanged(oldValue: oldValue)
        }
    }
    
    @Injected(\.repository) private var repository
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.galleryImageProviderFlow) var galleryImageProviderFlow
    
    var confirmAllowed: Bool {
        switch self.source {
        case .drawing: return self.canvasView.drawing.strokes.count > 0
        case .image: return self.signatureGalleryImage != nil
        case .camera: return self.signatureCameraImage != nil
        }
    }
    
    private var currentSignatureImage: UIImage? {
        switch self.source {
        case .drawing: return self.canvasView.drawing.signatureImage
        case .image: return self.signatureGalleryImage
        case .camera: return self.signatureCameraImage
        }
    }
    
    private let onConfirm: ConfirmationCallback
    
    init(onConfirm: @escaping ConfirmationCallback) {
        self.onConfirm = onConfirm
        super.init()
        self.canvasView.delegate = self
    }
    
    func onClearButtonPressed() {
        self.canvasView.drawing = PKDrawing()
    }
    
    func toggleShouldSave() {
        self.shouldSaveSignature = !self.shouldSaveSignature
    }
    
    func onConfirmButtonPressed() {
        
        guard let currentSignatureImage else {
            assertionFailure("Missing expected current signature image!")
            return
        }
        
        var signature = Signature(image: currentSignatureImage)
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
    
    func onSelectImageButtonPressed() {
        self.startGetImageFlow()
    }
    
    func onTakePictureButtonPressed() {
        self.startTakePictureFlow()
    }
    
    private func onSourceChanged(oldValue: SignatureSource) {
        if oldValue != self.source {
            switch self.source {
            case .drawing:
                break
            case .image:
                if self.signatureGalleryImage == nil {
                    self.startGetImageFlow()
                }
            case .camera:
                if self.signatureCameraImage == nil {
                    self.startTakePictureFlow()
                }
            }
        }
    }
    
    private func startGetImageFlow() {
        self.galleryImageProviderFlow.startFlow { [weak self] in
            self?.signatureGalleryImage = $0
        }
    }
    
    private func startTakePictureFlow() {
        debugPrint(for: self, message: "Start Take Picture Flow")
        self.signatureCameraImage = Self.getTestImage()
    }
    
    private static func getTestImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: K.Misc.SignatureSize, format: format)
        return renderer.image { context in
            let firstColor = UIColor(ColorPalette.primaryBG)
            let secondColor = UIColor(ColorPalette.secondaryText)
            let thirdColor = UIColor(ColorPalette.extra.opacity(0.6))
            UIColor.gray.setStroke()
            context.stroke(renderer.format.bounds)
            firstColor.setFill()
            context.fill(CGRect(x: renderer.format.bounds.width / 2 - renderer.format.bounds.height,
                                y: 1,
                                width: renderer.format.bounds.height - 2,
                                height: renderer.format.bounds.height - 2))
            secondColor.setFill()
            context.fill(CGRect(x: renderer.format.bounds.width / 2,
                                y: 1,
                                width: renderer.format.bounds.height - 2,
                                height: renderer.format.bounds.height - 2), blendMode: .multiply)
            
            thirdColor.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: renderer.format.bounds.width / 2 - renderer.format.bounds.height / 2,
                                                     y: 1,
                                                     width: renderer.format.bounds.height - 2,
                                                     height: renderer.format.bounds.height - 2))
        }
    }
}

extension PdfSignatureCanvasViewModel: PKCanvasViewDelegate {
    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        if self.canvasView == canvasView {
            self.objectWillChange.send()
        }
    }
}
