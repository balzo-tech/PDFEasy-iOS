//
//  ScanCaptureService.swift
//  PdfExpert
//
//  The camera behind the scanner: a capture session that does two jobs at once
//  — a video stream the document detector watches frame by frame, and a photo
//  output that takes the actual page at full resolution.
//
//  It is deliberately separate from `CameraService` (the "take a picture of
//  something" camera used by Image to PDF). A scanner needs live edge detection,
//  a shutter that can fire itself, and a torch that stays on between pages;
//  bolting all of that onto the general-purpose camera would have made both
//  harder to follow.
//
//  Threading follows the same rule as `CameraService`: the session is
//  configured and started on its own queue — `startRunning()` blocks until the
//  hardware is warm — while everything `@Published` is written on the main
//  queue, which is also where the control methods are called from.
//

import Foundation
import AVFoundation
import UIKit
import CoreImage

/// What the flash does when a page is taken.
enum ScanFlashMode: String, CaseIterable, Identifiable, Sendable {

    case auto
    case on
    case off

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .on: return String(localized: "On")
        case .off: return String(localized: "Off")
        }
    }

    var systemImage: String {
        switch self {
        case .auto: return "bolt.badge.automatic.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        }
    }

    var captureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }

    func next() -> ScanFlashMode {
        switch self {
        case .auto: return .on
        case .on: return .off
        case .off: return .auto
        }
    }
}

/// One page, as it came off the shutter.
struct ScanCaptureResult {
    let image: UIImage
    /// Where the detector thinks the page is, or `nil` when it found nothing.
    let quad: ScanQuad?
    /// True when the automatic shutter fired it rather than the user.
    let isAutomatic: Bool
}

final class ScanCaptureService: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case running
        /// The user said no to the camera. The UI offers a trip to Settings.
        case permissionDenied
        /// No usable camera, or the session refused to configure.
        case unavailable
    }

    // MARK: Published state

    @Published private(set) var state: State = .idle
    /// The page currently in view, in normalized upright coordinates, or `nil`
    /// when nothing page-shaped is in frame.
    @Published private(set) var detectedQuad: ScanQuad? = nil
    /// How close the automatic shutter is to firing, 0…1. Drives the ring around
    /// the shutter button, so the user can see it coming instead of being
    /// surprised by it.
    @Published private(set) var autoShutterProgress: Double = 0
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var zoomFactor: CGFloat = 1
    /// Angle the preview layer's connection should carry, tracked live so the
    /// picture stays upright when an iPad is turned.
    @Published private(set) var previewRotationAngle: CGFloat = 90
    /// Size of the frames the detector sees, after the connection has rotated
    /// them. The overlay needs it to map a normalized quad onto a preview that
    /// is filling — and therefore cropping — the screen.
    @Published private(set) var bufferSize: CGSize = .zero
    @Published var flashMode: ScanFlashMode = .auto
    @Published var isAutoShutterEnabled: Bool = true {
        didSet { if !self.isAutoShutterEnabled { self.resetSteadiness() } }
    }

    let session = AVCaptureSession()

    /// Handed a page as soon as the shutter — finger or automatic — produces one.
    var onPageCaptured: ((ScanCaptureResult) -> Void)? = nil

    // MARK: Session plumbing

    private let sessionQueue = DispatchQueue(label: "eu.balzo.pdfexpert.scan.session")
    private let videoQueue = DispatchQueue(label: "eu.balzo.pdfexpert.scan.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservations: [NSKeyValueObservation] = []
    private var isConfigured = false

    private let detector = DocumentDetector()
    /// One detection at a time: frames arrive faster than Vision can answer, and
    /// queueing them would show the user where the page was half a second ago.
    private var isDetecting = false
    private var captureDelegates: [Int64: ScanPhotoCaptureDelegate] = [:]

    // MARK: Automatic shutter

    private var steadyFrameCount = 0
    private var lastSteadyQuad: ScanQuad? = nil
    /// Set after a capture so the shutter does not fire again on the page that
    /// was just taken; cleared as soon as the camera is pointed somewhere else.
    private var needsMovementToRearm = false
    private var lastCapturedQuad: ScanQuad? = nil

    // MARK: - Lifecycle

    /// Asks for the camera if needed, configures the session once, and starts it.
    @MainActor
    func start() async {
        guard await self.ensureAuthorized() else {
            self.state = .permissionDenied
            return
        }

        if !self.isConfigured {
            guard await self.configureSession() else {
                self.state = .unavailable
                return
            }
            self.isConfigured = true
        }

        self.state = .running
        self.sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        self.setTorch(on: false)
        self.sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
        self.state = .idle
        self.detectedQuad = nil
        self.resetSteadiness()
    }

    private func ensureAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureSession() async -> Bool {
        await withCheckedContinuation { continuation in
            self.sessionQueue.async {
                continuation.resume(returning: self.configureSessionOnQueue())
            }
        }
    }

    /// Runs on `sessionQueue`.
    private func configureSessionOnQueue() -> Bool {
        self.session.beginConfiguration()

        self.session.sessionPreset = .photo

        // The dual wide camera focuses closer than the plain wide one, which is
        // exactly the distance a page is held at.
        let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)

        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              self.session.canAddInput(input) else {
            self.session.commitConfiguration()
            return false
        }
        self.session.addInput(input)
        self.videoDeviceInput = input

        guard self.session.canAddOutput(self.photoOutput) else {
            self.session.commitConfiguration()
            return false
        }
        self.session.addOutput(self.photoOutput)
        self.photoOutput.maxPhotoQualityPrioritization = .quality

        self.videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        // Detection is slower than the frame rate by design; dropping frames is
        // how the overlay stays in step with what the camera sees.
        self.videoOutput.alwaysDiscardsLateVideoFrames = true
        self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
        guard self.session.canAddOutput(self.videoOutput) else {
            self.session.commitConfiguration()
            return false
        }
        self.session.addOutput(self.videoOutput)

        self.session.commitConfiguration()

        // Focus and exposure for a flat page held in front of the phone.
        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }

        let zoom = device.videoZoomFactor
        DispatchQueue.main.async {
            self.zoomFactor = zoom
            self.startTrackingRotation(for: device)
        }
        return true
    }

    /// Keeps the photo and video connections pointed the way the user is holding
    /// the device. Without it a scan taken on an iPad in landscape comes out on
    /// its side, and the detected quad no longer lines up with the preview.
    private func startTrackingRotation(for device: AVCaptureDevice) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        self.rotationCoordinator = coordinator
        self.previewRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        // The coordinator reports the device's real orientation, which is what
        // "upright" means here — the app's own window is locked to portrait on a
        // phone, so watching the interface orientation would never fire.
        self.rotationObservations = [
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                DispatchQueue.main.async {
                    self?.previewRotationAngle = angle
                    self?.applyRotationAngles()
                }
            }
        ]
        self.applyRotationAngles()
    }

    private func applyRotationAngles() {
        guard let coordinator = self.rotationCoordinator else { return }
        // The *preview* angle, deliberately, for the still capture too: it is the
        // one the preview layer uses, so the frames the detector sees, the quad
        // drawn over them and the photo finally taken all live in the same space.
        // Using the capture angle here would let the two diverge — and then the
        // overlay would sit next to the page rather than on it.
        let captureAngle = coordinator.videoRotationAngleForHorizonLevelPreview
        self.sessionQueue.async {
            for output in [self.photoOutput as AVCaptureOutput, self.videoOutput as AVCaptureOutput] {
                guard let connection = output.connection(with: .video),
                      connection.isVideoRotationAngleSupported(captureAngle) else { continue }
                connection.videoRotationAngle = captureAngle
            }
        }
    }

    // MARK: - Camera controls

    /// `point` is in capture-device space (0…1, origin top left of the sensor),
    /// which is what the preview layer converts a tap into.
    func focus(at point: CGPoint) {
        guard let device = self.videoDeviceInput?.device else { return }
        self.sessionQueue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        }
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = self.videoDeviceInput?.device else { return }
        let clamped = min(max(factor, 1), min(device.activeFormat.videoMaxZoomFactor, 8))
        self.zoomFactor = clamped
        self.sessionQueue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        }
    }

    /// The torch lights the preview while framing; the still capture uses the
    /// flash instead, set per shot from `flashMode`.
    func setTorch(on: Bool) {
        guard let device = self.videoDeviceInput?.device, device.hasTorch else { return }
        self.sessionQueue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }

    // MARK: - Capture

    func capture(automatic: Bool = false) {
        guard self.state == .running, !self.isCapturing else { return }
        self.isCapturing = true
        self.resetSteadiness()

        let quad = self.detectedQuad
        var settings = AVCapturePhotoSettings()
        if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        if self.videoDeviceInput?.device.isFlashAvailable == true {
            settings.flashMode = self.flashMode.captureMode
        }
        settings.photoQualityPrioritization = .quality
        let settingsId = settings.uniqueID

        let delegate = ScanPhotoCaptureDelegate { [weak self] image in
            DispatchQueue.main.async {
                self?.finishCapture(image: image,
                                    previewQuad: quad,
                                    isAutomatic: automatic,
                                    settingsId: settingsId)
            }
        }
        self.captureDelegates[settingsId] = delegate

        self.applyRotationAngles()
        self.sessionQueue.async { [photoOutput] in
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func finishCapture(image: UIImage?,
                               previewQuad: ScanQuad?,
                               isAutomatic: Bool,
                               settingsId: Int64) {
        self.captureDelegates[settingsId] = nil
        self.isCapturing = false
        guard let image else { return }

        self.lastCapturedQuad = previewQuad
        self.needsMovementToRearm = true

        // The preview's quad is a usable fallback, but the still is sharper and
        // higher-resolution: re-running detection on it gives a crop that lines
        // up with the pixels actually being straightened.
        Task { [weak self] in
            guard let self else { return }
            var quad = previewQuad
            if let ciImage = ScanImageProcessor.ciImage(from: image),
               let detected = await self.detector.detect(in: ciImage) {
                quad = detected
            }
            await MainActor.run {
                self.onPageCaptured?(ScanCaptureResult(image: image, quad: quad, isAutomatic: isAutomatic))
            }
        }
    }

    // MARK: - Detection

    /// Runs on `videoQueue`.
    fileprivate func handle(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.bufferSize != size { self.bufferSize = size }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isDetecting, !self.isCapturing, self.state == .running else { return }
            self.isDetecting = true
            Task { [weak self] in
                // The connection already rotates the buffer to match how the
                // device is held, so Vision is looking at an upright frame.
                let quad = await self?.detector.detect(in: pixelBuffer, orientation: .up)
                await MainActor.run {
                    guard let self else { return }
                    self.isDetecting = false
                    self.updateDetection(quad)
                }
            }
        }
    }

    private func updateDetection(_ quad: ScanQuad?) {
        self.detectedQuad = quad
        guard self.isAutoShutterEnabled, !self.isCapturing else { return }

        guard let quad else {
            // The page left the frame: that counts as pointing the camera
            // somewhere else, so the shutter can arm again.
            self.needsMovementToRearm = false
            self.resetSteadiness()
            return
        }

        if self.needsMovementToRearm {
            if let last = self.lastCapturedQuad, quad.maximumCornerDistance(from: last) > 0.12 {
                self.needsMovementToRearm = false
            } else {
                return
            }
        }

        // Steadiness is measured against the last frame, not against the first:
        // a slow drift never accumulates into "steady", while a hand that has
        // simply come to rest counts immediately.
        if let previous = self.lastSteadyQuad,
           quad.maximumCornerDistance(from: previous) <= K.Misc.ScanAutoShutterTolerance {
            self.steadyFrameCount += 1
        } else {
            self.steadyFrameCount = 0
        }
        self.lastSteadyQuad = quad
        self.autoShutterProgress = min(Double(self.steadyFrameCount) / Double(K.Misc.ScanAutoShutterSteadyFrames), 1)

        if self.steadyFrameCount >= K.Misc.ScanAutoShutterSteadyFrames {
            self.capture(automatic: true)
        }
    }

    private func resetSteadiness() {
        self.steadyFrameCount = 0
        self.lastSteadyQuad = nil
        self.autoShutterProgress = 0
    }
}

// MARK: - Video frames

extension ScanCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        self.handle(sampleBuffer: sampleBuffer)
    }
}

// MARK: - Photo delegate

/// `AVCapturePhotoOutput` does not keep its delegate alive, so the service holds
/// these in a dictionary until they report back.
private final class ScanPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {

    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            self.completion(nil)
            return
        }
        self.completion(image)
    }
}
