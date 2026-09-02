//
//  PassportPhotoView.swift
//  PdfExpert
//
//  The identity photo, shown at the size it will be printed and with the lines
//  the office measures drawn over it.
//
//  The guides are the argument. Any app can output a 35 × 45 mm JPEG; showing
//  where the crown, the eyes and the chin landed inside that rectangle is what
//  turns "trust us" into "look". They are on by default for that reason, and the
//  checklist under the photo is the same idea in words — including, deliberately,
//  the checks that passed, because a list that only ever appears when something
//  is wrong is a list nobody believes when it stays quiet.
//

import SwiftUI

struct PassportPhotoView: ViewModifier {

    @ObservedObject var viewModel: PassportPhotoViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: self.$viewModel.editorShow) {
                PassportPhotoEditorView(viewModel: self.viewModel)
            }
            // Outside the cover: an error here closes it, and an alert on a
            // screen that is leaving is an alert nobody sees.
            .showError(self.$viewModel.error)
    }
}

struct PassportPhotoEditorView: View {

    @ObservedObject var viewModel: PassportPhotoViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { self.horizontalSizeClass == .regular }

    var body: some View {
        ToolScreen(title: String(localized: "Passport photo"),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        self.preview
                        self.documentButton
                        self.backgroundPicker
                        self.outputPicker
                        self.checklist
                        self.actions
                    }
                    .padding(DS.Spacing.md)
                    .readableColumn()
                }
            }
        }
        .sheet(isPresented: self.$viewModel.specPickerShow) {
            PassportSpecPickerView(selection: self.$viewModel.spec)
        }
        .sheet(item: self.$viewModel.shareUrl,
               onDismiss: { self.viewModel.onShareDismiss() }) { item in
            ActivityViewController(activityItems: [item.url],
                                   thumbnail: item.thumbnail,
                                   title: item.url.lastPathComponent)
        }
        .showSubscriptionView(self.$viewModel.monetizationShow,
                              onComplete: { self.viewModel.onMonetizationClose() })
        .alert(String(localized: "Saved to Photos"), isPresented: self.$viewModel.savedToPhotosAlertShow, actions: {
            Button("Ok", role: .cancel, action: {})
        }, message: {
            Text("The image has been saved to your photos.")
        })
        .alertPhotoLibraryPermission(isPresented: self.$viewModel.photosPermissionAlertShow)
    }

    // MARK: - The photo

    /// The aspect of whatever is on screen — the country's frame, or the sheet
    /// of paper. Holding the container to it exactly is what lets the guide
    /// lines be drawn as plain fractions of the height: the image fills its box
    /// rather than sitting somewhere inside it.
    private var previewAspect: CGFloat {
        switch self.viewModel.output {
        case .photo: return self.viewModel.spec.aspectRatio
        case .sheet: return self.viewModel.sheetFormat.size.width / self.viewModel.sheetFormat.size.height
        }
    }

    /// The tallest the photo is allowed to get on screen. Turned into a *width*
    /// cap below, which is the only way to bound a fixed-ratio box without
    /// letting the box and the picture inside it come apart: cap the height
    /// directly and the container keeps the full column width, the overlays
    /// attach to that wider box, and the guide lines end up measuring something
    /// other than the photo.
    private var previewHeightCap: CGFloat { self.isWideLayout ? 460 : 340 }

    private var preview: some View {
        Color.clear
            .aspectRatio(self.previewAspect, contentMode: .fit)
            .overlay {
                if let image = self.viewModel.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    ColorPalette.surface
                }
            }
            .overlay {
                if self.viewModel.showsGuides, self.viewModel.output == .photo {
                    PassportGuidesOverlay(spec: self.viewModel.spec)
                }
            }
            .overlay {
                if self.viewModel.isProcessing {
                    ZStack {
                        Color.black.opacity(0.25)
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                    .strokeBorder(ColorPalette.separator, lineWidth: 0.5)
            }
            .overlay(alignment: .topTrailing) {
                if self.viewModel.output == .photo {
                    Button {
                        withAnimation(DS.Motion.quick) { self.viewModel.showsGuides.toggle() }
                    } label: {
                        Image(systemName: self.viewModel.showsGuides ? "ruler.fill" : "ruler")
                            .font(forCategory: .body2)
                            .padding(DS.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                    .floatingGlassCapsule()
                    .padding(DS.Spacing.xs)
                    .accessibilityLabel(Text("Show measurement guides"))
                }
            }
            .frame(maxWidth: self.previewHeightCap * self.previewAspect)
            .frame(maxWidth: .infinity)
            .animation(DS.Motion.quick, value: self.viewModel.previewImage)
            .accessibilityLabel(Text("Preview of the identity photo"))
    }

    // MARK: - Which document

    private var documentButton: some View {
        Button {
            self.viewModel.specPickerShow = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(self.viewModel.spec.flag)
                    .font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.viewModel.spec.displayName)
                        .font(forCategory: .body3)
                        .foregroundStyle(ColorPalette.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text("\(self.viewModel.spec.sizeDescription) · \(self.viewModel.spec.minimumDPI) dpi")
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textTertiary)
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity)
            .contentCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Document format"))
        .accessibilityValue(Text(self.viewModel.spec.displayName))
    }

    // MARK: - Backdrop

    private var backgroundPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Background")
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: DS.Spacing.sm) {
                ForEach(self.viewModel.availableBackgrounds) { background in
                    Button {
                        self.viewModel.background = background
                    } label: {
                        self.swatch(for: background)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(background.title))
                    .accessibilityAddTraits(background == self.viewModel.background ? [.isButton, .isSelected] : .isButton)
                }
                Spacer(minLength: 0)
            }
            if !self.viewModel.canReplaceBackground {
                Text("The subject could not be separated from this photo, so the background is kept as it is.")
                    .font(forCategory: .caption2)
                    .foregroundStyle(ColorPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let note = self.viewModel.spec.note {
                Text(note)
                    .font(forCategory: .caption2)
                    .foregroundStyle(ColorPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(self.viewModel.isProcessing)
    }

    private func swatch(for background: PassportBackground) -> some View {
        let isSelected = background == self.viewModel.background
        return VStack(spacing: DS.Spacing.xxs) {
            ZStack {
                if let color = background.cgColor {
                    Color(cgColor: color)
                } else {
                    // "Keep original" gets a photograph rather than a colour: it
                    // is the only option whose result cannot be guessed from a
                    // swatch.
                    Image(systemName: "photo")
                        .font(forCategory: .body2)
                        .foregroundStyle(ColorPalette.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ColorPalette.surface)
                }
            }
            .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
            .clipShape(.circle)
            .overlay {
                Circle()
                    .strokeBorder(isSelected ? ColorPalette.accent : ColorPalette.separator,
                                  lineWidth: isSelected ? 3 : 1)
            }
            Text(background.title)
                .font(forCategory: .caption2)
                .foregroundStyle(isSelected ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 72)
        .contentShape(.rect)
    }

    // MARK: - One photo or a sheet of them

    private var outputPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Picker("", selection: self.$viewModel.output) {
                ForEach(PassportPhotoViewModel.Output.allCases) { output in
                    Text(output.title).tag(output)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if self.viewModel.output == .sheet {
                Picker(String(localized: "Paper"), selection: self.$viewModel.sheetFormat) {
                    ForEach(self.viewModel.sheetFormats) { format in
                        Text("\(format.title) — \(format.subtitle)").tag(format)
                    }
                }
                .pickerStyle(.menu)
                .tint(ColorPalette.accent)

                Text("\(self.viewModel.photosPerSheet) photos on one sheet, with lines to cut along.")
                    .font(forCategory: .caption2)
                    .foregroundStyle(ColorPalette.textTertiary)
            }
        }
        .disabled(self.viewModel.isProcessing)
    }

    // MARK: - What is wrong with it

    private var checklist: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            self.checklistHeader
            ForEach(self.viewModel.checks.filter { $0.outcome != .pass }) { check in
                PassportCheckRow(check: check)
            }
            let passed = self.viewModel.checks.filter { $0.outcome == .pass }
            if !passed.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        ForEach(passed) { check in
                            PassportCheckRow(check: check)
                        }
                    }
                    .padding(.top, DS.Spacing.xs)
                } label: {
                    Text("\(passed.count) checks passed")
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                .tint(ColorPalette.textSecondary)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
        .opacity(self.viewModel.checks.isEmpty ? 0 : 1)
    }

    private var checklistHeader: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: self.headerSymbol)
                .foregroundStyle(self.headerColor)
            Text(self.headerTitle)
                .font(forCategory: .headline)
                .foregroundStyle(ColorPalette.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var headerTitle: String {
        switch self.viewModel.worstOutcome {
        case .pass:
            return String(localized: "Ready to print")
        case .warning:
            return String(localized: "Worth a look")
        case .failure:
            return String(localized: "Needs fixing")
        }
    }

    private var headerSymbol: String {
        switch self.viewModel.worstOutcome {
        case .pass: return "checkmark.seal.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.seal.fill"
        }
    }

    private var headerColor: Color {
        switch self.viewModel.worstOutcome {
        case .pass: return ColorPalette.success
        case .warning: return ColorPalette.premium
        case .failure: return ColorPalette.danger
        }
    }

    // MARK: - Ways out

    private var actions: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button(action: { self.viewModel.saveToPhotos() }) {
                Label("Save to Photos", systemImage: "square.and.arrow.down")
                    .font(forCategory: .button)
                    .frame(maxWidth: .infinity)
                    .frame(height: DS.Size.tapTarget)
            }
            .buttonStyle(.glassProminent)

            HStack(spacing: DS.Spacing.xs) {
                Button(action: { self.viewModel.share() }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(forCategory: .button)
                        .frame(maxWidth: .infinity)
                        .frame(height: DS.Size.tapTarget)
                }
                .buttonStyle(.glass)

                Button(action: { self.viewModel.createPdf() }) {
                    Label("Make a PDF", systemImage: "doc.badge.plus")
                        .font(forCategory: .button)
                        .frame(maxWidth: .infinity)
                        .frame(height: DS.Size.tapTarget)
                }
                .buttonStyle(.glass)
            }
        }
        .disabled(!self.viewModel.canExport)
    }
}

// MARK: - The lines the office measures

/// Crown, eyes and chin, drawn where the specification puts them.
///
/// Plain fractions of the height, because the container the overlay sits in has
/// been held to the photo's own aspect ratio. The eye line is drawn only where
/// the country states one — inventing it everywhere would be showing a
/// measurement nobody is going to take.
struct PassportGuidesOverlay: View {

    let spec: PassportPhotoSpec

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                self.line(at: self.spec.crownFractionFromTop * proxy.size.height,
                          width: proxy.size.width,
                          label: String(localized: "Crown"))
                self.line(at: self.spec.chinFractionFromTop * proxy.size.height,
                          width: proxy.size.width,
                          label: String(localized: "Chin"))
                if let eyes = self.spec.eyeLineFractionFromTop {
                    let mid = (eyes.lowerBound + eyes.upperBound) / 2
                    self.line(at: mid * proxy.size.height,
                              width: proxy.size.width,
                              label: String(localized: "Eyes"))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The label is an *overlay* on the rule rather than a sibling in a stack.
    ///
    /// A stack takes the height of its tallest child — the caption, not the
    /// hairline — so the offset would place the top of the caption at `y` and
    /// leave the line half a caption below where the measurement actually falls.
    /// Off by seven points on a 45 mm print is off by a millimetre, on the one
    /// screen whose whole claim is that the millimetres are right.
    private func line(at y: CGFloat, width: CGFloat, label: String) -> some View {
        Rectangle()
            .fill(ColorPalette.accent.opacity(0.85))
            .frame(width: width, height: 1)
            .overlay(alignment: .leading) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(ColorPalette.accent.opacity(0.85), in: .capsule)
                    .padding(.leading, 4)
                    .fixedSize()
            }
            .offset(y: y)
    }
}

// MARK: - One line of the checklist

struct PassportCheckRow: View {

    let check: PassportPhotoCheck

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: self.check.systemImage)
                .foregroundStyle(self.tint)
                .font(forCategory: .body2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(self.check.title)
                    .font(forCategory: .body2)
                    .foregroundStyle(ColorPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let advice = self.check.advice {
                    Text(advice)
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch self.check.outcome {
        case .pass: return ColorPalette.success
        case .warning: return ColorPalette.premium
        case .failure: return ColorPalette.danger
        }
    }
}

// MARK: - Choosing the country

/// The catalog, searchable.
///
/// Searchable because the list is long enough to scroll past what you want and
/// because the words people use are not the words on the rows: somebody types
/// `fototessera` or `foto carnet` or `증명사진`, none of which is a country name.
struct PassportSpecPickerView: View {

    @Binding var selection: PassportPhotoSpec

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var specs: [PassportPhotoSpec] {
        PassportPhotoCatalog.search(self.query, in: PassportPhotoCatalog.ordered())
    }

    var body: some View {
        NavigationStack {
            List(self.specs) { spec in
                Button {
                    self.selection = spec
                    self.dismiss()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(spec.flag)
                            .font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spec.displayName)
                                .font(forCategory: .body2)
                                .foregroundStyle(ColorPalette.textPrimary)
                            Text(spec.sizeDescription)
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textSecondary)
                        }
                        Spacer(minLength: 0)
                        if spec.id == self.selection.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(ColorPalette.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .searchable(text: self.$query, prompt: Text("Country or document"))
            .navigationTitle(String(localized: "Photo format"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                // The disclaimer belongs on the screen where the promise is
                // made. Every size in the list comes from the issuing authority,
                // and none of that makes us the authority.
                Text("Sizes follow each country's official rules. The office issuing your document has the final say.")
                    .font(forCategory: .caption2)
                    .foregroundStyle(ColorPalette.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
    }
}

extension View {

    func showPassportPhotoView(viewModel: PassportPhotoViewModel) -> some View {
        self.modifier(PassportPhotoView(viewModel: viewModel))
    }
}
