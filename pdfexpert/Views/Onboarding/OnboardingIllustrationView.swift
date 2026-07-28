//
//  OnboardingIllustrationView.swift
//  PdfExpert
//
//  The onboarding's stage: one document, four things happening to it.
//
//  The page is deliberately a *single* view that survives across the four steps
//  rather than one picture per step. It tilts, shifts and settles as the steps
//  change, and the props — the viewfinder, the file stack, the signature, the
//  chat bubbles — arrive on top of it and leave again. What the eye follows is
//  one document being worked on, which is also the honest description of the
//  app; four separate illustrations would only be a slideshow of features.
//
//  These used to be screenshots of the app as it looked two years ago: a tab bar
//  that no longer exists, and Microsoft's and Apple's own icons along for the
//  ride. Drawn in SwiftUI they cost nothing to keep true, follow the light and
//  dark themes, and borrow only the colors a spreadsheet or a slide deck is
//  recognised by — never the marks themselves, same rule as the paywall collage.
//

import SwiftUI

enum OnboardingIllustration: CaseIterable, Hashable {
    case scan
    case convert
    case signature
    case chat
    case toolbox
}

struct OnboardingIllustrationView: View {

    let illustration: OnboardingIllustration

    /// The scene is laid out once at this size and scaled to whatever room it is
    /// given, so every measurement below can be a plain number.
    private static let baseSize = CGSize(width: 260, height: 300)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Self.baseSize.width,
                            geometry.size.height / Self.baseSize.height)
            ZStack {
                self.glow
                PageCard()
                    .rotationEffect(.degrees(self.pageTilt))
                    .offset(x: self.pageOffset.width, y: self.pageOffset.height)
                    .scaleEffect(self.pageScale)
                self.props
            }
            .frame(width: Self.baseSize.width, height: Self.baseSize.height)
            .scaleEffect(scale)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(self.transition, value: self.illustration)
        }
        .accessibilityHidden(true)
    }

    private var transition: Animation? {
        self.reduceMotion ? nil : .smooth(duration: 0.55, extraBounce: 0.12)
    }

    /// The wash of color behind the page. Its hue belongs to the step, so the
    /// whole stage changes temperature as the steps do — the slowest and least
    /// noticeable part of the morph, and the one that sells it.
    private var glow: some View {
        RadialGradient(colors: [self.tint.opacity(0.26), self.tint.opacity(0.07), .clear],
                       center: .center,
                       startRadius: 0,
                       endRadius: 190)
        .blur(radius: 22)
    }

    @ViewBuilder private var props: some View {
        switch self.illustration {
        case .scan: ScanProps()
        case .convert: ConvertProps()
        case .signature: SignatureProps()
        case .chat: ChatProps()
        case .toolbox: ToolboxProps()
        }
    }

    // MARK: - What the page does at each step

    private var tint: Color {
        switch self.illustration {
        case .scan: return ColorPalette.categoryCreate
        case .convert: return ColorPalette.accent
        case .signature: return ColorPalette.categoryEdit
        case .chat: return ColorPalette.categoryAi
        case .toolbox: return ColorPalette.categoryOrganize
        }
    }

    private var pageTilt: Double {
        switch self.illustration {
        case .scan: return -3
        case .convert: return 4
        case .signature: return -2
        case .chat: return -5
        case .toolbox: return 0
        }
    }

    private var pageOffset: CGSize {
        switch self.illustration {
        case .scan: return CGSize(width: 0, height: -12)
        case .convert: return CGSize(width: 42, height: 6)
        case .signature: return CGSize(width: 0, height: 0)
        case .chat: return CGSize(width: -62, height: -16)
        case .toolbox: return CGSize(width: 0, height: 0)
        }
    }

    private var pageScale: CGFloat {
        switch self.illustration {
        case .scan: return 1
        case .convert: return 1.02
        case .signature: return 1.12
        case .chat: return 0.92
        // Small enough for the ring of tools to close around it without
        // crowding: the document is what they are all for.
        case .toolbox: return 0.62
        }
    }
}

// MARK: - The document

/// A sheet of paper with some writing on it — the same sheet at every step, so
/// it can move rather than be replaced. Always light, in both themes: a document
/// is a white page, and a dark grey rectangle reads as a placeholder.
private struct PageCard: View {

    private let width: CGFloat = 134
    private let height: CGFloat = 178
    private let lines: [CGFloat] = [1, 0.9, 0.96, 0.72, 0.88, 0.5]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ColorPalette.signatureInk.opacity(0.55))
                .frame(width: (self.width - 28) * 0.62, height: 6)
                .padding(.bottom, 3)
            ForEach(Array(self.lines.enumerated()), id: \.offset) { _, ratio in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(ColorPalette.signatureInkSecondary.opacity(0.28))
                    .frame(width: (self.width - 28) * ratio, height: 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: self.width, height: self.height, alignment: .topLeading)
        .background(ColorPalette.signatureSheet,
                    in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(ColorPalette.signatureInk.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
    }
}

/// The rounded tinted tile the whole app labels a tool with.
private struct ToolTile: View {

    let systemImage: String
    let tint: Color
    var side: CGFloat = 46

    var body: some View {
        Image(systemName: self.systemImage)
            .font(.system(size: self.side * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: self.side, height: self.side)
            .background(self.tint, in: .rect(cornerRadius: self.side * 0.28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: self.side * 0.28, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: self.tint.opacity(0.45), radius: 10, y: 5)
    }
}

/// Props fade and scale in from behind the page, and leave the same way.
private extension AnyTransition {
    static var prop: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }
}

// MARK: - Scan

/// A page inside the viewfinder with the scan line running down it. The corner
/// brackets are what a camera aimed at paper looks like on every phone, so they
/// say "scanner" before the shutter underneath does.
private struct ScanProps: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeping = false
    @State private var framed = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [.clear,
                                              ColorPalette.categoryCreate.opacity(0.9),
                                              .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 130, height: 26)
                .blur(radius: 3)
                .offset(y: self.sweeping ? 74 : -74)
                .mask {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .frame(width: 134, height: 178)
                }
                .offset(y: -12)

            ViewfinderCorners()
                .stroke(ColorPalette.categoryCreate,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 172, height: 214)
                .shadow(color: ColorPalette.categoryCreate.opacity(0.55), radius: 10)
                .scaleEffect(self.framed ? 1 : 1.12)
                .opacity(self.framed ? 1 : 0)
                .offset(y: -12)

            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(ColorPalette.categoryCreate, in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5) }
                .shadow(color: ColorPalette.categoryCreate.opacity(0.5), radius: 14, y: 7)
                .offset(y: 118)
        }
        .transition(.prop)
        .onAppear {
            withAnimation(.snappy(duration: 0.45, extraBounce: 0.3)) { self.framed = true }
            guard !self.reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                self.sweeping = true
            }
        }
    }
}

/// Four brackets, one per corner.
private struct ViewfinderCorners: Shape {

    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.2
        var path = Path()
        for corner in [(rect.minX, rect.minY, 1.0, 1.0),
                       (rect.maxX, rect.minY, -1.0, 1.0),
                       (rect.minX, rect.maxY, 1.0, -1.0),
                       (rect.maxX, rect.maxY, -1.0, -1.0)] {
            let (x, y, dx, dy) = corner
            path.move(to: CGPoint(x: x + length * dx, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + length * dy))
        }
        return path
    }
}

// MARK: - Convert

/// Three file formats folding into one document. The tiles drop in one after the
/// other and the arrow keeps nudging towards the page.
private struct ConvertProps: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var nudging = false

    private static let files: [(symbol: String, tint: Color, tilt: Double, shift: CGFloat)] = [
        ("doc.richtext", ColorPalette.formatWord, -9, -8),
        ("tablecells", ColorPalette.formatExcel, -3, 4),
        ("rectangle.on.rectangle", ColorPalette.formatPowerPoint, -12, -6),
    ]

    var body: some View {
        ZStack {
            Text(verbatim: "PDF")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(ColorPalette.danger, in: .capsule)
                .rotationEffect(.degrees(4))
                .offset(x: 82, y: 74)

            VStack(spacing: -4) {
                ForEach(Array(Self.files.enumerated()), id: \.offset) { index, file in
                    ToolTile(systemImage: file.symbol, tint: file.tint)
                        .rotationEffect(.degrees(file.tilt))
                        .offset(x: file.shift)
                        .offset(x: self.landed ? 0 : -34, y: self.landed ? 0 : 14)
                        .opacity(self.landed ? 1 : 0)
                        .animation(.snappy(duration: 0.45, extraBounce: 0.28)
                            .delay(Double(index) * 0.08), value: self.landed)
                }
            }
            .offset(x: -70, y: -4)

            Image(systemName: "arrow.right")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(ColorPalette.accent)
                .shadow(color: ColorPalette.accent.opacity(0.5), radius: 8)
                .offset(x: self.nudging ? -30 : -40, y: -2)
        }
        .transition(.prop)
        .onAppear {
            self.landed = true
            guard !self.reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                self.nudging = true
            }
        }
    }
}

// MARK: - Signature

/// The signature is drawn, stroke by stroke, and then the document is stamped as
/// signed. Watching a line being written is the one bit of this screen worth
/// waiting a beat for.
private struct SignatureProps: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var written: CGFloat = 0
    @State private var stamped = false

    var body: some View {
        ZStack {
            VStack(spacing: 5) {
                SignatureStroke()
                    .trim(from: 0, to: self.written)
                    .stroke(ColorPalette.signatureInk,
                            style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 118, height: 34)
                Rectangle()
                    .fill(ColorPalette.accent.opacity(0.55))
                    .frame(width: 118, height: 1)
            }
            .offset(y: 60)

            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(ColorPalette.accent, in: .circle)
                .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5) }
                .shadow(color: ColorPalette.accent.opacity(0.5), radius: 12, y: 6)
                .scaleEffect(self.stamped ? 1 : 0.2)
                .opacity(self.stamped ? 1 : 0)
                .offset(x: 74, y: 86)
        }
        .transition(.prop)
        .onAppear {
            guard !self.reduceMotion else {
                self.written = 1
                self.stamped = true
                return
            }
            withAnimation(.easeInOut(duration: 1.1)) { self.written = 1 }
            withAnimation(.snappy(duration: 0.5, extraBounce: 0.45).delay(1.0)) {
                self.stamped = true
            }
        }
    }
}

/// A handwritten flourish. Bezier rather than a font: at this size a script
/// typeface would only show that it is a typeface. A tall opening stroke, then
/// loops that lose height as they go — even amplitudes read as a sine wave.
private struct SignatureStroke: Shape {

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.03, y: h * 0.86))
        path.addCurve(to: CGPoint(x: w * 0.16, y: h * 0.10),
                      control1: CGPoint(x: w * 0.02, y: h * 0.46),
                      control2: CGPoint(x: w * 0.07, y: h * 0.10))
        path.addCurve(to: CGPoint(x: w * 0.24, y: h * 0.90),
                      control1: CGPoint(x: w * 0.24, y: h * 0.10),
                      control2: CGPoint(x: w * 0.30, y: h * 0.56))
        path.addCurve(to: CGPoint(x: w * 0.39, y: h * 0.28),
                      control1: CGPoint(x: w * 0.20, y: h * 1.04),
                      control2: CGPoint(x: w * 0.30, y: h * 0.22))
        path.addCurve(to: CGPoint(x: w * 0.51, y: h * 0.78),
                      control1: CGPoint(x: w * 0.45, y: h * 0.32),
                      control2: CGPoint(x: w * 0.45, y: h * 0.84))
        path.addCurve(to: CGPoint(x: w * 0.64, y: h * 0.38),
                      control1: CGPoint(x: w * 0.57, y: h * 0.72),
                      control2: CGPoint(x: w * 0.57, y: h * 0.36))
        path.addCurve(to: CGPoint(x: w * 0.75, y: h * 0.70),
                      control1: CGPoint(x: w * 0.70, y: h * 0.42),
                      control2: CGPoint(x: w * 0.70, y: h * 0.74))
        path.addCurve(to: CGPoint(x: w * 0.97, y: h * 0.34),
                      control1: CGPoint(x: w * 0.83, y: h * 0.64),
                      control2: CGPoint(x: w * 0.88, y: h * 0.52))
        return path
    }
}

// MARK: - Chat

/// A question about the document, then the answer arriving.
private struct ChatProps: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var asked = false
    @State private var answered = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            self.bubble(text: String(localized: "What does this say?"),
                        fill: ColorPalette.surfaceElevated,
                        textColor: ColorPalette.textPrimary,
                        bordered: true)
            .scaleEffect(self.asked ? 1 : 0.7, anchor: .bottomTrailing)
            .opacity(self.asked ? 1 : 0)

            self.bubble(text: String(localized: "Here is the short version"),
                        fill: ColorPalette.accent,
                        textColor: .white,
                        bordered: false,
                        icon: "sparkles")
            .scaleEffect(self.answered ? 1 : 0.7, anchor: .bottomLeading)
            .opacity(self.answered ? 1 : 0)
        }
        .offset(x: 22, y: 46)
        .transition(.prop)
        .onAppear {
            guard !self.reduceMotion else {
                self.asked = true
                self.answered = true
                return
            }
            withAnimation(.snappy(duration: 0.4, extraBounce: 0.3).delay(0.15)) { self.asked = true }
            withAnimation(.snappy(duration: 0.45, extraBounce: 0.32).delay(0.6)) { self.answered = true }
        }
    }

    private func bubble(text: String,
                        fill: Color,
                        textColor: Color,
                        bordered: Bool,
                        icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(fill, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            if bordered {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ColorPalette.separator, lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

// MARK: - Toolbox

/// The rest of the app, closing in a ring around the document.
///
/// A ring rather than the paywall's scattered drift: that one says "there is a
/// lot here", this one says "all of it works on the thing in the middle". The
/// eight are one per family plus the ones people go looking for by name, and
/// they arrive one after another, going round.
private struct ToolboxProps: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gathered = false

    private static let tools: [(symbol: String, tint: Color)] = [
        ("arrow.trianglehead.merge", ColorPalette.categoryOrganize),
        ("scissors", ColorPalette.categoryOrganize),
        ("textformat", ColorPalette.categoryEdit),
        ("text.viewfinder", ColorPalette.categoryEdit),
        ("lock.shield", ColorPalette.categoryProtect),
        ("arrow.up.forward.square", ColorPalette.categoryExport),
        ("book", ColorPalette.categoryRead),
        ("rotate.right", ColorPalette.categoryOrganize),
    ]

    private static let radius: CGFloat = 104

    var body: some View {
        ZStack {
            ForEach(Array(Self.tools.enumerated()), id: \.offset) { index, tool in
                let angle = Angle.degrees(Double(index) / Double(Self.tools.count) * 360 - 90)
                ToolTile(systemImage: tool.symbol, tint: tool.tint, side: 42)
                    .offset(x: cos(angle.radians) * Self.radius * (self.gathered ? 1 : 0.35),
                            y: sin(angle.radians) * Self.radius * (self.gathered ? 1 : 0.35))
                    .scaleEffect(self.gathered ? 1 : 0.4)
                    .opacity(self.gathered ? 1 : 0)
                    .animation(self.reduceMotion
                               ? nil
                               : .snappy(duration: 0.5, extraBounce: 0.3).delay(Double(index) * 0.06),
                               value: self.gathered)
            }
        }
        .transition(.prop)
        .onAppear {
            self.gathered = true
        }
    }
}

#Preview("Stage") {
    struct Stage: View {
        @State private var illustration: OnboardingIllustration = .scan
        var body: some View {
            VStack {
                OnboardingIllustrationView(illustration: self.illustration)
                    .frame(height: 320)
                Picker("", selection: self.$illustration) {
                    Text(verbatim: "Scan").tag(OnboardingIllustration.scan)
                    Text(verbatim: "Convert").tag(OnboardingIllustration.convert)
                    Text(verbatim: "Sign").tag(OnboardingIllustration.signature)
                    Text(verbatim: "Chat").tag(OnboardingIllustration.chat)
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
