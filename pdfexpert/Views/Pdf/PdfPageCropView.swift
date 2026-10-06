//
//  PdfPageCropView.swift
//  PdfExpert
//
//  Cropping the page on screen to an area of itself.
//
//  People photograph and scan pages and then could not get rid of the desk round
//  the edge, or keep just the table they needed: the editor had no crop. This is
//  it — the whole page as it is shown (turned the way it is turned), a rectangle
//  over it with a handle at each corner and side, and the rest of the page dimmed.
//
//  SwiftUI only, on purpose. The image cropper the signature flow uses (Mantis)
//  does not draw under Mac Catalyst — see `ImageCropFlow.swift` — and a page crop
//  that only works on a phone is half a tool.
//
//  The page is drawn whole rather than as currently cropped, so a crop can be
//  made larger again as well as smaller; the rectangle opens on the current crop.
//  "Reset" puts it back on the whole page, which undoes any crop made before.
//

import SwiftUI

/// The rectangle's arithmetic, kept out of the view so it can be tested. Every
/// rect here is in unit coordinates over the page as drawn: origin at the top
/// left, 0…1 across and down.
enum PageCropGeometry {

    /// What can be dragged: a corner, a side, or the whole rectangle from inside.
    enum Handle: String, CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
        case body

        var movesLeft: Bool { [.topLeft, .left, .bottomLeft].contains(self) }
        var movesRight: Bool { [.topRight, .right, .bottomRight].contains(self) }
        var movesTop: Bool { [.topLeft, .top, .topRight].contains(self) }
        var movesBottom: Bool { [.bottomLeft, .bottom, .bottomRight].contains(self) }

        /// Where the handle sits on the rectangle, as fractions of its size.
        var anchor: UnitPoint {
            switch self {
            case .topLeft: return .topLeading
            case .top: return .top
            case .topRight: return .topTrailing
            case .right: return .trailing
            case .bottomRight: return .bottomTrailing
            case .bottom: return .bottom
            case .bottomLeft: return .bottomLeading
            case .left: return .leading
            case .body: return .center
            }
        }

        var isCorner: Bool { [.topLeft, .topRight, .bottomRight, .bottomLeft].contains(self) }
    }

    static let unit = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// The rectangle after dragging `handle` by `delta` from `start`. Sides stop
    /// at the page's edge and at `minSize` from the opposite side; dragged from
    /// inside, the rectangle keeps its size and stops at the edge.
    static func rect(dragging handle: Handle,
                     from start: CGRect,
                     by delta: CGSize,
                     minSize: CGSize) -> CGRect {
        if handle == .body {
            let x = min(max(start.minX + delta.width, 0), 1 - start.width)
            let y = min(max(start.minY + delta.height, 0), 1 - start.height)
            return CGRect(x: x, y: y, width: start.width, height: start.height)
        }
        var (left, top, right, bottom) = (start.minX, start.minY, start.maxX, start.maxY)
        if handle.movesLeft {
            left = min(max(left + delta.width, 0), right - minSize.width)
        }
        if handle.movesRight {
            right = max(min(right + delta.width, 1), left + minSize.width)
        }
        if handle.movesTop {
            top = min(max(top + delta.height, 0), bottom - minSize.height)
        }
        if handle.movesBottom {
            bottom = max(min(bottom + delta.height, 1), top + minSize.height)
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// Whether a rectangle is the whole page, give or take a rounding error.
    static func isWholePage(_ rect: CGRect) -> Bool {
        abs(rect.minX) < 0.001 && abs(rect.minY) < 0.001
            && abs(rect.maxX - 1) < 0.001 && abs(rect.maxY - 1) < 0.001
    }
}

struct PdfPageCropView: View {

    @ObservedObject var viewModel: PdfEditViewModel

    @Environment(\.dismiss) private var dismiss

    /// The page drawn whole, turned as it is shown. Nil while it is being drawn.
    @State private var pageImage: UIImage? = nil
    /// The rectangle, in unit coordinates over `pageImage`.
    @State private var cropRect: CGRect = PageCropGeometry.unit
    /// The rectangle as it was when the current drag began. A drag reports how
    /// far it has gone in total, so it is applied to this and not to `cropRect`.
    @State private var dragStart: CGRect? = nil
    @State private var hasLoaded = false

    /// The smallest the rectangle can get, on screen: about a fingertip either
    /// way, so the handles on opposite sides never sit on top of each other.
    private static let minimumSide: CGFloat = 56
    /// Every handle answers to at least this much of the screen.
    private static let handleTarget: CGFloat = DS.Size.tapTarget
    private static let canvasSpace = "pageCropCanvas"

    var body: some View {
        ToolScreen(title: String(localized: "Crop page")) {
            self.canvas
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorPalette.background)
                .safeAreaInset(edge: .bottom) {
                    self.bottomBar
                }
        }
        // The confirming button carries the accent through the glass style, not
        // through a background of its own: in a toolbar on iOS 26 a background
        // ends up under the bar's material (a white blob).
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    self.apply()
                } label: {
                    Text("Apply")
                }
                .buttonStyle(.glassProminent)
                .tint(ColorPalette.accent)
                .disabled(self.pageImage == nil || !self.viewModel.canEditPages)
                .accessibilityIdentifier("cropPage.apply")
            }
        }
        .onAppear(perform: self.load)
    }

    // MARK: - The page and the rectangle

    @ViewBuilder private var canvas: some View {
        if let image = self.pageImage {
            GeometryReader { geometry in
                let fitted = ScanPreviewGeometry.fittedRect(imageSize: image.size, in: geometry.size)
                let crop = self.viewRect(for: self.cropRect, in: fitted)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: fitted.midX, y: fitted.midY)
                        // For UI tests, which drag the handles by where the page
                        // is drawn. The element reports the whole canvas as its
                        // frame, so the page's shape rides in the identifier
                        // (VoiceOver does not read it) and the test fits it in.
                        .accessibilityLabel(Text("Crop page"))
                        .accessibilityIdentifier(String(format: "cropPage.page@%.4f",
                                                        image.size.width / max(image.size.height, 1)))

                    // Everything outside the rectangle, dimmed: the page and a
                    // hole cut out of it, filled even-odd.
                    Path { path in
                        path.addRect(fitted)
                        path.addRect(crop)
                    }
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                    self.frameLines(crop)

                    // Inside first, so the handles on the edge are on top of it
                    // and win the touch where the two overlap.
                    self.handle(.body, crop: crop, fitted: fitted)
                    ForEach(PageCropGeometry.Handle.allCases.filter { $0 != .body }, id: \.self) { handle in
                        self.handle(handle, crop: crop, fitted: fitted)
                    }
                }
                // A `GeometryReader` puts its child in the top left corner; every
                // position above is worked out in this frame, so it has to be
                // exactly the reader's own.
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(.rect)
                .coordinateSpace(.named(Self.canvasSpace))
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The outline and its thirds, the way the system's photo crop draws them.
    private func frameLines(_ crop: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                    let x = crop.minX + crop.width * fraction
                    let y = crop.minY + crop.height * fraction
                    path.move(to: CGPoint(x: x, y: crop.minY))
                    path.addLine(to: CGPoint(x: x, y: crop.maxY))
                    path.move(to: CGPoint(x: crop.minX, y: y))
                    path.addLine(to: CGPoint(x: crop.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.45), lineWidth: 0.5)
            Path { path in path.addRect(crop) }
                .stroke(Color.white, lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func handle(_ handle: PageCropGeometry.Handle, crop: CGRect, fitted: CGRect) -> some View {
        let anchor = handle.anchor
        let center = CGPoint(x: crop.minX + crop.width * anchor.x,
                             y: crop.minY + crop.height * anchor.y)
        let size: CGSize = {
            switch handle {
            // Inside the rectangle, less a margin the edge handles keep for
            // themselves.
            case .body:
                return CGSize(width: max(crop.width - Self.handleTarget, 1),
                              height: max(crop.height - Self.handleTarget, 1))
            // The sides take the length of their edge between the corners, so a
            // drag anywhere along an edge moves it.
            case .top, .bottom:
                return CGSize(width: max(crop.width - Self.handleTarget, Self.handleTarget),
                              height: Self.handleTarget)
            case .left, .right:
                return CGSize(width: Self.handleTarget,
                              height: max(crop.height - Self.handleTarget, Self.handleTarget))
            default:
                return CGSize(width: Self.handleTarget, height: Self.handleTarget)
            }
        }()

        self.handleMark(handle)
            .frame(width: size.width, height: size.height)
            .contentShape(.rect)
            .position(center)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.canvasSpace))
                    .onChanged { value in
                        let start = self.dragStart ?? self.cropRect
                        if self.dragStart == nil { self.dragStart = start }
                        guard fitted.width > 0, fitted.height > 0 else { return }
                        let delta = CGSize(width: value.translation.width / fitted.width,
                                           height: value.translation.height / fitted.height)
                        let minSize = CGSize(width: min(Self.minimumSide / fitted.width, 1),
                                             height: min(Self.minimumSide / fitted.height, 1))
                        self.cropRect = PageCropGeometry.rect(dragging: handle,
                                                              from: start,
                                                              by: delta,
                                                              minSize: minSize)
                    }
                    .onEnded { _ in self.dragStart = nil }
            )
            // Dragging is not something VoiceOver can do with these; Apply and
            // Reset are the two buttons, and they are reachable.
            .accessibilityHidden(true)
    }

    /// What a handle looks like. The touch area is the frame around it; this is
    /// only the mark in the middle of it.
    @ViewBuilder private func handleMark(_ handle: PageCropGeometry.Handle) -> some View {
        if handle == .body {
            Color.clear
        } else if handle.isCorner {
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.35), radius: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let horizontal = handle == .top || handle == .bottom
            Capsule()
                .fill(Color.white)
                .frame(width: horizontal ? 28 : 6, height: horizontal ? 6 : 28)
                .shadow(color: .black.opacity(0.35), radius: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func viewRect(for rect: CGRect, in fitted: CGRect) -> CGRect {
        CGRect(x: fitted.minX + rect.minX * fitted.width,
               y: fitted.minY + rect.minY * fitted.height,
               width: rect.width * fitted.width,
               height: rect.height * fitted.height)
    }

    // MARK: - Reset

    private var bottomBar: some View {
        HStack {
            SecondaryActionButton(title: String(localized: "Reset"),
                                  systemImage: "arrow.counterclockwise") {
                withAnimation(DS.Motion.smooth) {
                    self.cropRect = PageCropGeometry.unit
                }
            }
            .disabled(self.pageImage == nil || PageCropGeometry.isWholePage(self.cropRect))
            .accessibilityIdentifier("cropPage.reset")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, DS.Spacing.xs)
    }

    // MARK: - Actions

    private func load() {
        // `onAppear` runs again when something is pushed on top and popped; the
        // rectangle the user is working on must not jump back.
        guard !self.hasLoaded else { return }
        self.hasLoaded = true
        self.cropRect = self.viewModel.currentPageCropRect()
        self.viewModel.currentPageUncroppedImage { image in
            self.pageImage = image
        }
    }

    private func apply() {
        self.viewModel.cropCurrentPage(toNormalizedRect: self.cropRect)
        self.dismiss()
    }
}
