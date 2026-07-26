//
//  ScanCropView.swift
//  PdfExpert
//
//  "Adjust": drag the four corners onto the page.
//
//  It works on the *original* capture, unfiltered and unrotated, because that is
//  the frame the corners are measured against — showing the corrected page here
//  and asking the user to re-corner it would mean applying a correction to a
//  correction.
//
//  Each handle carries a loupe: a finger covers exactly the corner it is trying
//  to place, and without one the last few points are guesswork.
//

import SwiftUI

struct ScanCropView: View {

    let page: ScannedPage
    let onSave: (ScanQuad?) -> Void
    let onCancel: () -> Void

    @State private var quad: ScanQuad
    @State private var draggingCorner: Int? = nil

    /// How far the loupe sits from the finger, so it is not under it.
    private static let loupeOffset: CGFloat = 90
    private static let loupeSize: CGFloat = 110
    private static let loupeScale: CGFloat = 2.2

    init(page: ScannedPage, onSave: @escaping (ScanQuad?) -> Void, onCancel: @escaping () -> Void) {
        self.page = page
        self.onSave = onSave
        self.onCancel = onCancel
        self._quad = State(initialValue: page.quad ?? .full)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let rect = ScanPreviewGeometry.fittedRect(imageSize: self.page.original.size,
                                                          in: geometry.size)
                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: self.page.original)
                        .resizable()
                        .scaledToFit()

                    self.cropOverlay(in: rect)

                    if let corner = self.draggingCorner {
                        self.loupe(forCorner: corner, in: rect, container: geometry.size)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: self.onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let cleaned = self.quad.clamped().normalizedCorners()
                        // A quad that covers the whole frame is the same as no
                        // crop at all; storing nil keeps the pipeline from
                        // running a correction that does nothing.
                        self.onSave(cleaned.isFullFrame ? nil : cleaned)
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        withAnimation(DS.Motion.snappy) { self.quad = .full }
                    } label: {
                        Label("Select the whole page", systemImage: "square.dashed")
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Overlay

    private func cropOverlay(in rect: CGRect) -> some View {
        let points = self.quad.corners.map { corner in
            CGPoint(x: rect.minX + corner.x * rect.width,
                    y: rect.minY + corner.y * rect.height)
        }
        return ZStack {
            // Everything outside the quad dimmed, so the crop reads as a
            // selection rather than as a drawing on top of the photo.
            Path { path in
                path.addRect(CGRect(origin: .zero, size: CGSize(width: 10_000, height: 10_000)))
                path.addPath(ScanQuadOverlay.path(through: points))
            }
            .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            ScanQuadOverlay.path(through: points)
                .stroke(ColorPalette.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                .allowsHitTesting(false)

            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                self.handle(isActive: self.draggingCorner == index)
                    .position(point)
                    .gesture(self.dragGesture(forCorner: index, in: rect))
            }
        }
    }

    private func handle(isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: isActive ? 26 : 20, height: isActive ? 26 : 20)
            Circle()
                .strokeBorder(ColorPalette.accent, lineWidth: 3)
                .frame(width: isActive ? 26 : 20, height: isActive ? 26 : 20)
        }
        // A finger is wider than the dot it is aiming at.
        .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
        .contentShape(.circle)
        .animation(DS.Motion.quick, value: isActive)
    }

    private func dragGesture(forCorner index: Int, in rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                self.draggingCorner = index
                guard rect.width > 0, rect.height > 0 else { return }
                let normalized = CGPoint(x: (value.location.x - rect.minX) / rect.width,
                                         y: (value.location.y - rect.minY) / rect.height)
                self.setCorner(index, to: normalized)
            }
            .onEnded { _ in
                self.draggingCorner = nil
            }
    }

    private func setCorner(_ index: Int, to point: CGPoint) {
        let clamped = CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        var updated = self.quad
        switch index {
        case 0: updated.topLeft = clamped
        case 1: updated.topRight = clamped
        case 2: updated.bottomRight = clamped
        default: updated.bottomLeft = clamped
        }
        // Refuse the drag that would fold the quad over itself: the corrected
        // page would come out mirrored, and the user cannot see why.
        guard updated.isConvex else { return }
        self.quad = updated
    }

    // MARK: - Loupe

    private func loupe(forCorner index: Int, in rect: CGRect, container: CGSize) -> some View {
        let corner = self.quad.corners[index]
        let point = CGPoint(x: rect.minX + corner.x * rect.width,
                            y: rect.minY + corner.y * rect.height)
        // Above the finger, unless the finger is already at the top.
        let showBelow = point.y < Self.loupeOffset + Self.loupeSize / 2
        let center = CGPoint(x: min(max(point.x, Self.loupeSize / 2), container.width - Self.loupeSize / 2),
                             y: showBelow ? point.y + Self.loupeOffset : point.y - Self.loupeOffset)

        return Circle()
            .fill(.black)
            .frame(width: Self.loupeSize, height: Self.loupeSize)
            .overlay {
                Image(uiImage: self.page.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: rect.width * Self.loupeScale, height: rect.height * Self.loupeScale)
                    .offset(x: (rect.midX - point.x) * Self.loupeScale,
                            y: (rect.midY - point.y) * Self.loupeScale)
                    .clipShape(.circle)
                    .overlay {
                        // Crosshair on the exact spot the corner sits at.
                        Path { path in
                            path.move(to: CGPoint(x: Self.loupeSize / 2 - 12, y: Self.loupeSize / 2))
                            path.addLine(to: CGPoint(x: Self.loupeSize / 2 + 12, y: Self.loupeSize / 2))
                            path.move(to: CGPoint(x: Self.loupeSize / 2, y: Self.loupeSize / 2 - 12))
                            path.addLine(to: CGPoint(x: Self.loupeSize / 2, y: Self.loupeSize / 2 + 12))
                        }
                        .stroke(ColorPalette.accent, lineWidth: 1.5)
                    }
            }
            .clipShape(.circle)
            .overlay { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2) }
            .position(center)
            .allowsHitTesting(false)
    }
}
