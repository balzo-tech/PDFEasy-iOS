//
//  MemeCanvasView.swift
//  PdfExpert
//
//  The picture with the words on it, and the words are the controls.
//
//  Two things have to line up here, and only one of them is on screen: what the
//  canvas draws with SwiftUI text, and what `ImageCanvasUtility` later burns in
//  with UIKit. They agree because neither invents a number — both read the same
//  `Caption`, whose place and size are fractions of the picture, and both use
//  the same font and the same 92% line width. The canvas multiplies those
//  fractions by a few hundred points, the export by a few thousand.
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

    /// Which block the keyboard belongs to. Nil while nothing is being typed.
    @FocusState.Binding var editing: UUID?

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
                        // The rect comes from the same measurement the export
                        // uses, so the live text and the file land in the same
                        // place — and neither can start half outside the picture.
                        let frame = ImageCanvasUtility.captionFrame(caption,
                                                                    style: self.viewModel.style,
                                                                    in: box)
                        MemeCaptionView(
                            caption: caption,
                            box: box,
                            frame: frame,
                            style: self.viewModel.style,
                            isSelected: caption.id == self.viewModel.selectedCaptionId,
                            isEditing: self.editing == caption.id,
                            text: self.viewModel.textBinding(for: caption.id),
                            onSelect: {
                                self.viewModel.select(captionId: caption.id)
                                self.editing = caption.id
                            },
                            onMove: { self.viewModel.move(captionId: caption.id, by: $0) },
                            onScale: { self.viewModel.scale(captionId: caption.id, to: $0) }
                        )
                        .focused(self.$editing, equals: caption.id)
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
                .frame(width: box.width, height: box.height)
                .clipped()
                // Tapping the picture itself puts the handles away, which is also
                // how to see what the export will look like.
                .contentShape(.rect)
                .onTapGesture {
                    self.editing = nil
                    self.viewModel.select(captionId: nil)
                }
                .position(x: outer.size.width / 2, y: outer.size.height / 2)
            }
        }
    }

    /// The largest box of the given proportions that fits in `available`.
    private static func fitted(aspect: CGFloat, in available: CGSize) -> CGSize {
        guard aspect > 0, available.width > 0, available.height > 0 else { return .zero }
        let width = min(available.width, available.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }
}

/// One block of words: outlined text, draggable, pinchable, and a field when it
/// is being typed into.
private struct MemeCaptionView: View {

    let caption: ImageCanvasUtility.Caption
    let box: CGSize
    /// Where this block sits and how big it is, measured once by the shared
    /// code so the canvas cannot drift from the export.
    let frame: CGRect
    let style: ImageCanvasUtility.CaptionStyle
    let isSelected: Bool
    let isEditing: Bool
    @Binding var text: String
    let onSelect: () -> Void
    /// A move, as a fraction of the box.
    let onMove: (CGSize) -> Void
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
                                                                 scale: self.caption.scale)) }
    private var shown: String {
        self.style.isUppercased ? self.text.uppercased(with: .current) : self.text
    }

    var body: some View {
        Group {
            if self.isEditing {
                self.field
            } else {
                self.outlinedText
            }
        }
        .frame(width: self.lineWidth)
        .overlay { self.handles }
        .contentShape(.rect)
        .onTapGesture { self.onSelect() }
        .gesture(self.dragGesture)
        .gesture(self.pinchGesture)
    }

    // MARK: - Reading

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
    }

    private var label: some View {
        Text(self.shown.isEmpty ? " " : self.shown)
            .font(self.font)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: self.lineWidth)
    }

    private static let ring: [CGPoint] = [
        CGPoint(x: -1, y: -1), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: -1),
        CGPoint(x: -1, y: 0),                        CGPoint(x: 1, y: 0),
        CGPoint(x: -1, y: 1), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)
    ]

    // MARK: - Writing

    /// While typing, a plain field in the same type. The outline is dropped for
    /// the duration on purpose: a caret behind eight copies of itself is not
    /// something anyone can aim with.
    private var field: some View {
        TextField("", text: self.$text, axis: .vertical)
            .font(self.font)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(self.style.isUppercased ? .characters : .sentences)
            .foregroundStyle(Color(uiColor: self.style.fill))
            .tint(ColorPalette.accent)
            .padding(.horizontal, 4)
            .background(Color.black.opacity(0.45), in: .rect(cornerRadius: 6, style: .continuous))
            .frame(width: self.lineWidth)
    }

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
