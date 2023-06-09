//
//  CameraViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 30/03/23.
//

import Foundation
import AVFoundation
import Combine
import Factory
import UIKit

typealias ImageCapturedCallback = (UIImage) -> ()

extension Container {
    var cameraService: Factory<CameraService> {
        self { CameraService() }
    }
}

extension Container {
    var cameraViewModel: ParameterFactory<ImageCapturedCallback, CameraViewModel> {
        self { CameraViewModel(onImageCaptured: $0) }.shared
    }
}

final class CameraViewModel: ObservableObject {
    
    @Injected(\.cameraService) var cameraService
    
    @Published var error: CameraError?
    
    @Published var showAlertError: Bool = false
    
    @Published var isFlashOn = false
    
    @Published var willCapturePhoto = false
    
    var session: AVCaptureSession { self.cameraService.session }
    
    private var onImageCaptured: ImageCapturedCallback
    
    private var subscriptions = Set<AnyCancellable>()
    
    init(onImageCaptured: @escaping ImageCapturedCallback) {
        
        self.onImageCaptured = onImageCaptured
        
        self.cameraService.$photo.sink { [weak self] (photo) in
            if let photo = photo {
                self?.onImageCaptured(photo.image!)
            }
        }
        .store(in: &self.subscriptions)
        
        self.cameraService.$error.sink { [weak self] (error) in
            self?.error = error
            if nil != error {
                self?.showAlertError = true
            }
        }
        .store(in: &self.subscriptions)
        
        self.cameraService.$flashMode.sink { [weak self] (mode) in
            self?.isFlashOn = mode == .on
        }
        .store(in: &self.subscriptions)
        
        self.cameraService.$willCapturePhoto.sink { [weak self] (val) in
            self?.willCapturePhoto = val
        }
        .store(in: &self.subscriptions)
    }
    
    func configure() {
        self.cameraService.checkForPermissions()
        self.cameraService.configure()
    }
    
    func capturePhoto() {
        self.cameraService.capturePhoto(saveToLibrary: false)
    }
    
    func flipCamera() {
        self.cameraService.changeCamera()
    }
    
    func zoom(with factor: CGFloat) {
        self.cameraService.set(zoom: factor)
    }
    
    func switchFlash() {
        self.cameraService.flashMode = self.cameraService.flashMode == .on ? .off : .on
    }
}
