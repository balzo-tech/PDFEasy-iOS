//
//  ScanCameraPreview.swift
//  PdfExpert
//
//  The live camera picture, and the outline drawn on top of the page it has
//  found.
//
//  The preview fills the screen, which means it crops the frame; the detected
//  quad is normalized against the *whole* frame. `ScanPreviewGeometry` does that
//  conversion, and it is the reason the capture session pins its video and photo
//  connections to the same rotation angle the preview uses — with two angles in
//  play there is no single mapping to compute.
//

import SwiftUI
import AVFoundation

// MARK: - Preview layer

struct ScanCameraPreview: UIViewRepresentable {

    let session: AVCaptureSession
    let rotationAngle: CGFloat
    /// Reports where the user tapped, already converted to the capture device's
    /// own coordinate space, which is what focus and exposure want.
    var onFocusTap: ((CGPoint) -> Void)? = nil

    func makeUIView(context: Context) -> ScanPreviewUIView {
        let view = ScanPreviewUIView()
        view.previewLayer.session = self.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onTap = { layerPoint in
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            self.onFocusTap?(devicePoint)
        }
        return view
    }

    func updateUIView(_ uiView: ScanPreviewUIView, context: Context) {
        if let connection = uiView.previewLayer.connection,
           connection.isVideoRotationAngleSupported(self.rotationAngle),
           connection.videoRotationAngle != self.rotationAngle {
            connection.videoRotationAngle = self.rotationAngle
        }
    }
}

final class ScanPreviewUIView: UIView {

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // Safe by construction: `layerClass` above guarantees the type.
        self.layer as! AVCaptureVideoPreviewLayer
    }

    var onTap: ((CGPoint) -> Void)? = nil

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .black
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(recognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        self.onTap?(recognizer.location(in: self))
    }
}

// MARK: - Mapping

enum ScanPreviewGeometry {

    /// Maps a quad normalized against the camera frame onto a preview that is
    /// filling the view — so the same maths the layer applies, run in reverse.
    static func points(for quad: ScanQuad, bufferSize: CGSize, previewSize: CGSize) -> [CGPoint] {
        guard bufferSize.width > 0, bufferSize.height > 0,
              previewSize.width > 0, previewSize.height > 0 else {
            return quad.points(in: previewSize)
        }
        let scale = max(previewSize.width / bufferSize.width, previewSize.height / bufferSize.height)
        let scaledSize = CGSize(width: bufferSize.width * scale, height: bufferSize.height * scale)
        let offset = CGPoint(x: (scaledSize.width - previewSize.width) / 2,
                             y: (scaledSize.height - previewSize.height) / 2)
        return quad.corners.map { corner in
            CGPoint(x: corner.x * scaledSize.width - offset.x,
                    y: corner.y * scaledSize.height - offset.y)
        }
    }

    /// Same idea for a still image shown with `.scaledToFit`: the picture is
    /// letterboxed rather than cropped, so the rect it occupies is what the crop
    /// editor lays its handles over.
    static func fittedRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (containerSize.width - size.width) / 2,
                      y: (containerSize.height - size.height) / 2,
                      width: size.width,
                      height: size.height)
    }
}

// MARK: - Overlay

/// The outline over the page the camera has found. Absent when it has found
/// nothing — a box that stays on screen guessing is worse than no box, because
/// the user stops trusting it.
struct ScanQuadOverlay: View {

    let quad: ScanQuad?
    let bufferSize: CGSize
    var tint: Color = ColorPalette.accent

    var body: some View {
        GeometryReader { geometry in
            if let quad {
                let points = ScanPreviewGeometry.points(for: quad,
                                                        bufferSize: self.bufferSize,
                                                        previewSize: geometry.size)
                let path = Self.path(through: points)
                path.fill(self.tint.opacity(0.16))
                path.stroke(self.tint, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(self.tint)
                        .frame(width: 9, height: 9)
                        .position(point)
                }
            }
        }
        .allowsHitTesting(false)
        .animation(DS.Motion.quick, value: self.quad)
    }

    static func path(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
