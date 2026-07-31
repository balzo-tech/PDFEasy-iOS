//
//  ImportTutorialPageView.swift
//  PdfExpert
//
//  One step of "convert a file from another app", and the drawing that goes with
//  it.
//
//  The three drawings replace three screenshots: a Home Screen from two iOS
//  versions ago, a picture with the word "Open in" baked into the pixels — English
//  in every language — and a share sheet carrying Instagram, WhatsApp and the app's
//  own logo from when it was called something else. Drawn in SwiftUI they follow
//  the themes, translate with the rest of the screen, and borrow nobody's marks:
//  the same rule the onboarding stage already follows.
//
//  As over there, the file card is a *single* view across the three steps. It sits
//  in a list, lifts towards the share button, then shrinks to the top of the sheet
//  where the destination is picked. What the eye follows is one file making the
//  trip, which is exactly what the words say.
//

import SwiftUI

enum ImportTutorialStep: Int, CaseIterable, Hashable {
    /// The file, in whichever app it lives in.
    case find
    /// The share button above it.
    case share
    /// The destination list, with this app in it.
    case choose
}

struct ImportTutorialPageView: View {

    let step: ImportTutorialStep
    let title: String
    let description: String

    var body: some View {
        // Spacers on both sides of the pair rather than one between them: the
        // drawing and the words are one block, and it sits in the middle of
        // whatever room the step is given instead of the words falling to the
        // bottom of the screen.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ImportTutorialIllustrationView(step: self.step)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .layoutPriority(-1)
            Spacer().frame(height: DS.Spacing.lg)
            VStack(spacing: DS.Spacing.sm) {
                Text(self.title)
                    .font(forCategory: .title2)
                    .foregroundStyle(ColorPalette.textPrimary)
                Text(self.description)
                    .font(forCategory: .body1)
                    .foregroundStyle(ColorPalette.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DS.Spacing.xl)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Illustration

struct ImportTutorialIllustrationView: View {

    let step: ImportTutorialStep

    /// Laid out once at this size and scaled to whatever room it gets, so every
    /// measurement below can be a plain number.
    private static let baseSize = CGSize(width: 260, height: 280)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Self.baseSize.width,
                            geometry.size.height / Self.baseSize.height)
            ZStack {
                self.glow
                self.neighbours
                self.destinations
                FileCard()
                    .scaleEffect(self.cardScale)
                    .offset(x: self.cardOffset.width, y: self.cardOffset.height)
                self.shareButton
            }
            .frame(width: Self.baseSize.width, height: Self.baseSize.height)
            .scaleEffect(scale)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(self.transition, value: self.step)
        }
        .accessibilityHidden(true)
    }

    private var transition: Animation? {
        self.reduceMotion ? nil : .smooth(duration: 0.5, extraBounce: 0.12)
    }

    private var glow: some View {
        RadialGradient(colors: [ColorPalette.accent.opacity(0.24),
                                ColorPalette.accent.opacity(0.06),
                                .clear],
                       center: .center,
                       startRadius: 0,
                       endRadius: 180)
        .blur(radius: 22)
    }

    // MARK: The file, wherever it is

    private var cardScale: CGFloat {
        switch self.step {
        case .find: return 1
        case .share: return 1.06
        case .choose: return 0.78
        }
    }

    private var cardOffset: CGSize {
        switch self.step {
        case .find: return CGSize(width: 0, height: 0)
        case .share: return CGSize(width: 0, height: 22)
        case .choose: return CGSize(width: 0, height: -84)
        }
    }

    /// The other files in the list. They are what makes the middle one read as
    /// "the one you picked", so they only exist while the list does.
    @ViewBuilder private var neighbours: some View {
        if self.step == .find {
            VStack(spacing: DS.Spacing.sm) {
                FileRow(symbol: "tablecells", tint: ColorPalette.formatExcel)
                Spacer().frame(height: FileCard.height)
                FileRow(symbol: "rectangle.on.rectangle", tint: ColorPalette.formatPowerPoint)
            }
            .opacity(0.5)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    /// Step two: the button the whole step is about, with a ring going out of it
    /// so the eye lands there and not on the card.
    @ViewBuilder private var shareButton: some View {
        if self.step == .share {
            ShareButton()
                .offset(y: -78)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }

    /// Step three: where the file can go. Every destination but ours is a blank
    /// tile — naming the neighbours would mean drawing somebody else's logo, and
    /// the point of the step is which one is highlighted.
    @ViewBuilder private var destinations: some View {
        if self.step == .choose {
            DestinationSheet()
                .offset(y: 46)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Pieces

/// The file being converted: a card with the format's colour on it. Blue for a
/// text document because that is the file people arrive with — the colour, never
/// the mark.
private struct FileCard: View {

    static let width: CGFloat = 196
    static let height: CGFloat = 62

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(ColorPalette.formatWord,
                            in: .rect(cornerRadius: DS.Radius.icon, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(ColorPalette.textPrimary.opacity(0.55)).frame(width: 92, height: 6)
                Capsule().fill(ColorPalette.textPrimary.opacity(0.22)).frame(width: 58, height: 5)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .frame(width: Self.width, height: Self.height)
        .background(ColorPalette.surfaceElevated,
                    in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .strokeBorder(ColorPalette.accent.opacity(0.55), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
    }
}

/// One of the files the picked one sits between.
private struct FileRow: View {

    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: self.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(self.tint, in: .rect(cornerRadius: 9, style: .continuous))
            Capsule().fill(ColorPalette.textSecondary.opacity(0.35)).frame(width: 76, height: 5)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .frame(width: FileCard.width, height: 48)
        .background(ColorPalette.surface,
                    in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
    }
}

/// The share button, with one ring leaving it. A single ring rather than a
/// pulsing stack: it has to read as "press this", not as a notification.
private struct ShareButton: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanding = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(ColorPalette.accent.opacity(self.expanding ? 0 : 0.55), lineWidth: 2)
                .frame(width: 56, height: 56)
                .scaleEffect(self.expanding ? 1.7 : 1)
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                // The glyph's arrow sits above its box, so it hangs high in a
                // circle unless it is nudged back down.
                .offset(y: -1.5)
                .frame(width: 56, height: 56)
                .background(ColorPalette.accent, in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5) }
                .shadow(color: ColorPalette.accent.opacity(0.5), radius: 14, y: 7)
        }
        .onAppear {
            guard !self.reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                self.expanding = true
            }
        }
    }
}

/// The destinations a shared file can go to, ours among them and picked.
private struct DestinationSheet: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var picked = false

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ForEach(0..<2, id: \.self) { _ in self.blankDestination }
                self.appDestination
                self.blankDestination
            }
            VStack(spacing: DS.Spacing.xs) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule()
                        .fill(ColorPalette.textSecondary.opacity(0.18))
                        .frame(width: 168, height: 8)
                }
            }
        }
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.sm)
        .frame(width: 232)
        .background(ColorPalette.surface,
                    in: .rect(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(ColorPalette.separator, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 16, y: 8)
        .onAppear {
            guard !self.reduceMotion else { self.picked = true; return }
            withAnimation(.snappy(duration: 0.45, extraBounce: 0.4).delay(0.35)) {
                self.picked = true
            }
        }
    }

    private var blankDestination: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(ColorPalette.textSecondary.opacity(0.16))
            .frame(width: 42, height: 42)
    }

    /// This app: the red PDF badge it is recognised by, and a tick once it is the
    /// one chosen.
    private var appDestination: some View {
        ZStack(alignment: .topTrailing) {
            Text(verbatim: "PDF")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(ColorPalette.danger,
                            in: .rect(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: ColorPalette.danger.opacity(0.45), radius: 10, y: 5)

            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(ColorPalette.success, in: .circle)
                .overlay { Circle().strokeBorder(ColorPalette.surface, lineWidth: 2) }
                .scaleEffect(self.picked ? 1 : 0.2)
                .opacity(self.picked ? 1 : 0)
                .offset(x: 7, y: -7)
        }
        .scaleEffect(self.picked ? 1.08 : 1)
    }
}

#Preview("Steps") {
    struct Stage: View {
        @State private var step: ImportTutorialStep = .find
        var body: some View {
            VStack {
                ImportTutorialIllustrationView(step: self.step)
                    .frame(height: 300)
                // Label as a view, not as a `""` title: an empty string literal is
                // a localizable key, and every extraction writes a blank entry
                // into the catalog that the lint then reports.
                Picker(selection: self.$step) {
                    Text(verbatim: "Find").tag(ImportTutorialStep.find)
                    Text(verbatim: "Share").tag(ImportTutorialStep.share)
                    Text(verbatim: "Choose").tag(ImportTutorialStep.choose)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorPalette.background)
        }
    }
    return Stage()
}
