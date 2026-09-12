//
//  MemeCanvasView.swift
//  PdfExpert
//
//  The picture with the words on it. You select, drag and pinch here — you type
//  in the panel below.
//
//  The first version held a `TextField` over each block and tried to focus it by
//  putting `.focused` on the block's container. It never raised a keyboard, and
//  it could not have: `.focused` binds a *focusable* view, and a `ZStack` is not
//  one, so the binding had nothing to bind to. Worse, the same container carried
//  `onTapGesture` and a `DragGesture(minimumDistance: 2)`, which between them ate
//  every touch before a field underneath could have placed a caret anyway. The
//  result was the bug as reported: a block you could add and move, and no way on
//  earth to write in it.
//
//  Rather than untangle a caret from a drag handle, the typing left the canvas.
//  One field, in the panel, always reachable, always able to take focus — and
//  the comment the old field carried about "a caret behind eight copies of
//  itself" stops being a problem to manage and becomes a thing that cannot
//  happen. The canvas keeps what it is good at: showing exactly what the export
//  will look like, and letting a finger put the words where the joke needs them.
//
//  Two things have to line up here, and only one of them is on screen: what the
//  canvas draws with SwiftUI text, and what `ImageCanvasUtility` later burns in
//  with UIKit. They agree because neither invents a number — both read the same
//  `Caption`, whose place and size are fractions of the picture, and both use
//  the same face and the same 92% line width. The canvas multiplies those
//  fractions by a few hundred points, the export by a few thousand.
//
//  Alignment lives in the same two places for the same reason: the paragraph
//  style the export draws with and the `multilineTextAlignment` the canvas draws
//  with both come off `Caption.alignment`, and an anchored block takes its x from
//  `captionFrame` rather than from `center` — so the words sit against the same
//  margin on screen and in the file.
//
//  The letterbox is handled by measuring rather than by `aspectRatio`: a fitted
//  box is computed from the picture's own proportions, and everything —
//  the image, the text, the touches — is laid out inside that box. A caption
//  positioned against the *container* instead would drift away from the picture
//  on every photograph that is not exactly the shape of the screen.
//

import SwiftUI

struct MemeCanvasView: View {

    @ObservedObject var viewModel: MemeMakerViewModel

    /// Raised when a block is picked up, so the panel can put the keyboard in
    /// front of the field that writes into it. Selecting is the view's job;
    /// deciding that selecting means typing is the panel's.
    let onCaptionPicked: () -> Void

    var body: some View {
        GeometryReader { outer in
            if let image = self.viewModel.canvasImage {
                let box = Self.fitted(aspect: image.size.width / max(image.size.height, 1),
                                      in: outer.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: box.width, height: box.height)

                    ForEach(self.viewModel.captions) { caption in
                        // An empty block is *drawn* with a placeholder, so it has
                        // to be *measured* with one too: measured as the single
                        // space it really holds, the box would be a few points
                        // wide and the placeholder would spill out of it. The
                        // stored caption is untouched — it stays blank, and
                        // `captioned` still leaves it out of the file.
                        let shown = Self.displayed(caption)
                        // The rect comes from the same measurement the export
                        // uses, so the live text and the file land in the same
                        // place — and neither can start half outside the picture.
                        let frame = ImageCanvasUtility.captionFrame(shown,
                                                                    style: self.viewModel.style,
                                                                    in: box)
                        MemeCaptionView(
                            caption: shown,
                            isPlaceholder: caption.isBlank,
                            box: box,
                            frame: frame,
                            style: self.viewModel.style,
                            isSelected: caption.id == self.viewModel.selectedCaptionId,
                            onSelect: {
                                self.viewModel.select(captionId: caption.id)
                                self.onCaptionPicked()
                            },
                            onMove: { self.viewModel.move(captionId: caption.id, by: $0) },
                            onDragStart: { self.viewModel.unanchor(captionId: caption.id, atFractionX: $0) },
                            onScale: { self.viewModel.scale(captionId: caption.id, to: $0) }
                        )
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
                .frame(width: box.width, height: box.height)
                .clipped()
                // Tapping the picture itself puts the handles away, which is also
                // how to see what the export will look like.
                .contentShape(.rect)
                .onTapGesture {
                    self.viewModel.select(captionId: nil)
                }
                .position(x: outer.size.width / 2, y: outer.size.height / 2)
            }
        }
    }

    /// The caption as the canvas shows it: itself, or the placeholder when the
    /// user has not written in it yet. Keeps the id, so selection and dragging
    /// still reach the real block.
    private static func displayed(
        _ caption: ImageCanvasUtility.Caption
    ) -> ImageCanvasUtility.Caption {
        guard caption.isBlank else { return caption }
        var copy = caption
        copy.text = String(localized: "Your text")
        return copy
    }

    /// The largest box of the given proportions that fits in `available`.
    private static func fitted(aspect: CGFloat, in available: CGSize) -> CGSize {
        guard aspect > 0, available.width > 0, available.height > 0 else { return .zero }
        let width = min(available.width, available.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }
}

/// One block of words: outlined text, draggable and pinchable.
private struct MemeCaptionView: View {

    /// Already resolved for display by the canvas: a blank block arrives here
    /// carrying the placeholder, with `isPlaceholder` saying so.
    let caption: ImageCanvasUtility.Caption
    let isPlaceholder: Bool
    let box: CGSize
    /// Where this block sits and how big it is, measured once by the shared
    /// code so the canvas cannot drift from the export.
    let frame: CGRect
    let style: ImageCanvasUtility.CaptionStyle
    let isSelected: Bool
    let onSelect: () -> Void
    /// A move, as a fraction of the box.
    let onMove: (CGSize) -> Void
    /// Raised once when a drag begins, carrying where the block actually is —
    /// `frame.midX` as a fraction of the box. A block anchored to an edge has no
    /// meaningful `center.x`, and this is what gives it one back before it is
    /// moved, so it carries on from where it looks rather than jumping.
    let onDragStart: (CGFloat) -> Void
    /// A new absolute scale, as a fraction of the box height.
    let onScale: (CGFloat) -> Void

    /// Drag arrives as a total translation from where the finger went down;
    /// the model wants a step. The difference is kept here and cleared when the
    /// finger lifts.
    @State private var lastTranslation: CGSize = .zero
    /// The size the block had when the pinch started, so the gesture multiplies
    /// that rather than compounding on itself.
    @State private var scaleAtPinchStart: CGFloat? = nil

    private var fontSize: CGFloat { max(self.box.height * self.caption.scale, 1) }
    private var lineWidth: CGFloat { max(self.frame.width, 1) }
    private var font: Font { Font(ImageCanvasUtility.captionFont(forImageHeight: self.box.height,
                                                                 scale: self.caption.scale,
                                                                 face: self.style.face)) }
    private var textAlignment: TextAlignment {
        switch self.caption.alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private var shown: String {
        self.style.isUppercased
            ? self.caption.text.uppercased(with: .current)
            : self.caption.text
    }

    var body: some View {
        self.outlinedText
            .frame(width: self.lineWidth)
            .overlay { self.handles }
            .contentShape(.rect)
            .onTapGesture { self.onSelect() }
            .gesture(self.dragGesture)
            .gesture(self.pinchGesture)
            // One element for the block, not nine: the outline is the same
            // string drawn eight times around the fill, and every one of those
            // copies is a `Text` that VoiceOver would otherwise read out.
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("memeCaptionBlock")
            .accessibilityLabel(Text(self.shown))
            .accessibilityAddTraits(self.isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// SwiftUI has no text stroke, so the outline is the same string drawn eight
    /// times around the fill. It is not the glyph-accurate outline UIKit draws in
    /// the export, but at this size the eye cannot tell, and it costs nothing.
    private var outlinedText: some View {
        let offset = self.fontSize * self.style.strokeScale * 0.5
        return ZStack {
            ForEach(Self.ring, id: \.self) { point in
                self.label
                    .foregroundStyle(Color(uiColor: self.style.stroke))
                    .offset(x: point.x * offset, y: point.y * offset)
            }
            self.label
                .foregroundStyle(Color(uiColor: self.style.fill))
        }
        .opacity(self.isPlaceholder ? 0.55 : 1)
    }

    private var label: some View {
        Text(self.shown)
            .font(self.font)
            .multilineTextAlignment(self.textAlignment)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: self.lineWidth)
    }

    private static let ring: [CGPoint] = [
        CGPoint(x: -1, y: -1), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: -1),
        CGPoint(x: -1, y: 0),                        CGPoint(x: 1, y: 0),
        CGPoint(x: -1, y: 1), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)
    ]

    @ViewBuilder private var handles: some View {
        if self.isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(ColorPalette.accent,
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .padding(-6)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if !self.isSelected { self.onSelect() }
                if self.lastTranslation == .zero, self.box.width > 0 {
                    self.onDragStart(self.frame.midX / self.box.width)
                }
                let step = CGSize(width: value.translation.width - self.lastTranslation.width,
                                  height: value.translation.height - self.lastTranslation.height)
                self.lastTranslation = value.translation
                guard self.box.width > 0, self.box.height > 0 else { return }
                self.onMove(CGSize(width: step.width / self.box.width,
                                   height: step.height / self.box.height))
            }
            .onEnded { _ in self.lastTranslation = .zero }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let base = self.scaleAtPinchStart ?? self.caption.scale
                if self.scaleAtPinchStart == nil { self.scaleAtPinchStart = base }
                self.onScale(base * value)
            }
            .onEnded { _ in self.scaleAtPinchStart = nil }
    }
}
