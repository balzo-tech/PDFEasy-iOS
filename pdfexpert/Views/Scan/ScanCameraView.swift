//
//  ScanCameraView.swift
//  PdfExpert
//
//  The capture screen: a full-bleed preview with the found page outlined on it,
//  and as little chrome as a scanner can get away with.
//
//  Everything that is not the page itself is glass over the picture rather than
//  a bar beside it — on a phone held at arm's length over a document, screen
//  real estate spent on chrome is framing the user cannot do.
//

import SwiftUI

struct ScanCameraView: View {

    @ObservedObject var viewModel: DocumentScanViewModel
    let onClose: () -> Void

    @ObservedObject private var capture: ScanCaptureService

    @State private var filterPickerShow: Bool = false
    @State private var focusIndicator: CGPoint? = nil
    @State private var shutterFlash: Bool = false
    @State private var zoomAtGestureStart: CGFloat = 1

    init(viewModel: DocumentScanViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onClose = onClose
        self.capture = viewModel.capture
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch self.capture.state {
            case .permissionDenied:
                self.permissionView
            case .unavailable:
                self.unavailableView
            case .idle, .running:
                self.cameraView
            }
        }
        .statusBarHidden()
        .onAppear { self.viewModel.onCameraAppear() }
        .onDisappear { self.viewModel.onCameraDisappear() }
        .sheet(isPresented: self.$filterPickerShow) {
            ScanFilterPickerView(selection: self.$viewModel.captureFilter,
                                 page: self.viewModel.pages.last,
                                 viewModel: self.viewModel,
                                 appliesToAllTitle: String(localized: "Apply to the pages already taken"),
                                 onApplyToAll: { self.viewModel.setFilterForAllPages($0) })
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Camera

    private var cameraView: some View {
        ZStack {
            ScanCameraPreview(session: self.capture.session,
                              rotationAngle: self.capture.previewRotationAngle,
                              onPreviewLayerReady: { layer in
                self.capture.attach(previewLayer: layer)
            },
                              onFocusTap: { devicePoint in
                self.capture.focus(at: devicePoint)
            })
            .ignoresSafeArea()
            .overlay {
                ScanQuadOverlay(quad: self.capture.detectedQuad,
                                bufferSize: self.capture.bufferSize)
                    .ignoresSafeArea()
            }
            // Pinch to zoom, the gesture people already use in every camera.
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        self.capture.setZoom(self.zoomAtGestureStart * value.magnification)
                    }
                    .onEnded { _ in
                        self.zoomAtGestureStart = self.capture.zoomFactor
                    }
            )
            .onAppear { self.zoomAtGestureStart = self.capture.zoomFactor }

            // A white flash on capture: the one piece of feedback that reads even
            // when the phone is moving and the shutter sound is off.
            if self.shutterFlash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }

            VStack(spacing: 0) {
                self.topBar
                Spacer()
                self.hintLabel
                self.controlsRow
                self.shutterRow
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.md)
        }
        .onChange(of: self.capture.isCapturing) { _, isCapturing in
            guard isCapturing else { return }
            withAnimation(.easeOut(duration: 0.08)) { self.shutterFlash = true }
            withAnimation(.easeIn(duration: 0.18).delay(0.08)) { self.shutterFlash = false }
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button(action: self.onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
                    // Without this the tappable area is the glyph — fifteen
                    // points of cross in a forty-four point target — and the
                    // close button reads as not working, because most of it is
                    // not a button at all.
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .floatingGlassCapsule()
            .accessibilityLabel(Text("Close"))

            Spacer()

            if !self.viewModel.pages.isEmpty {
                Button {
                    self.viewModel.finish()
                } label: {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text(self.viewModel.pageCountText)
                            .font(forCategory: .button)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(height: DS.Size.tapTarget)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .floatingGlassCapsule(tint: ColorPalette.accent)
                .accessibilityLabel(Text("Finish the scan"))
            }
        }
        .padding(.top, DS.Spacing.xs)
    }

    /// One line of guidance, and only while it is still useful.
    @ViewBuilder private var hintLabel: some View {
        if self.capture.detectedQuad == nil {
            Text("Point the camera at a page")
                .font(forCategory: .body2)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .floatingGlassCapsule(interactive: false)
                .padding(.bottom, DS.Spacing.sm)
                .transition(.opacity)
        }
    }

    private var controlsRow: some View {
        HStack(spacing: DS.Spacing.xl) {
            CameraControlButton(title: String(localized: "Flash"),
                                systemImage: self.capture.flashMode.systemImage,
                                isActive: self.capture.flashMode != .off,
                                badge: self.capture.flashMode == .auto ? "A" : nil) {
                self.capture.flashMode = self.capture.flashMode.next()
            }

            CameraControlButton(title: String(localized: "Filters"),
                                systemImage: self.viewModel.captureFilter.systemImage,
                                isActive: self.viewModel.captureFilter != .original) {
                self.filterPickerShow = true
            }

            CameraControlButton(title: String(localized: "Shutter"),
                                systemImage: "camera.viewfinder",
                                isActive: self.capture.isAutoShutterEnabled,
                                badge: self.capture.isAutoShutterEnabled ? "A" : nil) {
                self.capture.isAutoShutterEnabled.toggle()
            }
        }
        .padding(.bottom, DS.Spacing.md)
    }

    /// The shutter is centred on the screen, not on what is left of it. It used
    /// to sit in an `HStack` between the thumbnail and a spacer of the same
    /// width — but the thumbnail only exists once a page has been taken, and an
    /// absent view has no width to balance, so before the first capture the
    /// shutter sat half a thumbnail to the left of centre, out of line with the
    /// three controls above it. A centred layer with the thumbnail laid over it
    /// cannot drift.
    private var shutterRow: some View {
        ShutterButton(progress: self.capture.autoShutterProgress,
                      isEnabled: self.capture.state == .running && !self.capture.isCapturing) {
            self.capture.capture()
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            self.lastPageThumbnail
                .frame(width: 58, height: 58)
        }
    }

    @ViewBuilder private var lastPageThumbnail: some View {
        if let page = self.viewModel.pages.last {
            Button {
                self.viewModel.review()
            } label: {
                ScanPageThumbnail(page: page, viewModel: self.viewModel)
                    .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                            .strokeBorder(.white.opacity(0.8), lineWidth: 1.5)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text(verbatim: "\(self.viewModel.pages.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ColorPalette.accent, in: .capsule)
                            .padding(3)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Review the scanned pages"))
        }
    }

    // MARK: - States

    private var permissionView: some View {
        ContentUnavailableView {
            Label("Camera access is off", systemImage: "camera.fill")
        } description: {
            Text("PDF Pro needs the camera to scan a document. You can turn it on in Settings.")
        } actions: {
            PrimaryActionButton(title: String(localized: "Open Settings")) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .frame(maxWidth: 260)
            Button("Cancel", action: self.onClose)
                .font(forCategory: .linkText)
        }
        .preferredColorScheme(.dark)
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label("Camera unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text("This device's camera could not be started.")
        } actions: {
            PrimaryActionButton(title: String(localized: "Close"), action: self.onClose)
                .frame(maxWidth: 220)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Controls

/// One of the small labelled round buttons under the preview.
struct CameraControlButton: View {

    let title: String
    let systemImage: String
    var isActive: Bool = false
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: self.systemImage)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(self.isActive ? ColorPalette.accent : .white)
                    .frame(width: 52, height: 52)
                    // The whole disc, not the icon inside it. Missing this is
                    // why a control could take two attempts: the first tap
                    // landed on glass that was not listening.
                    .contentShape(.circle)
                    .floatingGlassCapsule()
                    .overlay(alignment: .topTrailing) {
                        if let badge = self.badge {
                            Text(verbatim: badge)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.black)
                                .frame(width: 15, height: 15)
                                .background(ColorPalette.accent, in: .circle)
                        }
                    }
                Text(self.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(self.title))
        .accessibilityAddTraits(self.isActive ? [.isButton, .isSelected] : .isButton)
    }
}

/// The shutter, with the automatic countdown drawn around it.
struct ShutterButton: View {

    let progress: Double
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(.white)
                    .frame(width: 62, height: 62)
                Circle()
                    .trim(from: 0, to: self.progress)
                    .stroke(ColorPalette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Motion.quick, value: self.progress)
            }
            .opacity(self.isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!self.isEnabled)
        .accessibilityLabel(Text("Take a page"))
    }
}

/// A page as it is being rendered: the raw capture first, replaced by the
/// filtered version as soon as Core Image is done with it.
struct ScanPageThumbnail: View {

    let page: ScannedPage
    @ObservedObject var viewModel: DocumentScanViewModel

    var body: some View {
        Color.black.overlay {
            Image(uiImage: self.viewModel.preview(for: self.page,
                                                  maxDimension: K.Misc.ScanThumbnailMaxDimension)
                  ?? self.page.original)
                .resizable()
                .scaledToFill()
        }
        .clipped()
    }
}
