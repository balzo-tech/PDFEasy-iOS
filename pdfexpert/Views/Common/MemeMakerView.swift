//
//  MemeMakerView.swift
//  PdfExpert
//
//  A canvas, and two panels under it.
//
//  The first version put two text fields under the picture and locked one line
//  to the top and one to the bottom. It was easy to build and wrong to use: a
//  meme is made by putting words *where the joke needs them*. The second made
//  the picture the biggest thing on screen and let the words be dragged, which
//  was right — but it piled the styling, the gallery and the three ways out into
//  one strip, and it tried to take typing onto the canvas itself, where the
//  keyboard never came (see the note at the top of `MemeCanvasView`).
//
//  So the controls are now two named panels and you are only ever in one of
//  them. **Make** is everything that changes the picture: the words, the face,
//  the colour, the template. **Share** is the three ways out, and nothing else.
//
//  The split is not only tidiness. Moving to Share drops the keyboard and clears
//  the selection, so the canvas stops showing handles and dashed boxes and shows
//  the thing that is about to leave — the last look before it goes, for free.
//

import SwiftUI
import PhotosUI

struct MemeMakerView: ViewModifier {

    @ObservedObject var viewModel: MemeMakerViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: self.$viewModel.editorShow) {
                MemeMakerEditorView(viewModel: self.viewModel)
            }
            .showError(self.$viewModel.error)
    }
}

/// Which panel is under the canvas.
private enum MemePanel: String, CaseIterable, Identifiable {

    case make
    case share

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .make: return String(localized: "Make")
        case .share: return String(localized: "Share")
        }
    }
}

struct MemeMakerEditorView: View {

    @ObservedObject var viewModel: MemeMakerViewModel

    /// The one place text is typed. A single flag, not a per-block one: there is
    /// a single field and it always writes into whichever block is selected.
    @FocusState private var typing: Bool
    @State private var panel: MemePanel = .make
    @State private var pickedPhoto: PhotosPickerItem? = nil

    var body: some View {
        ToolScreen(title: String(localized: "Meme maker"),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                VStack(spacing: DS.Spacing.sm) {
                    self.canvas
                    self.panelPicker
                    Group {
                        switch self.panel {
                        case .make: self.makePanel
                        case .share: self.sharePanel
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
                .readableColumn()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { self.typing = false }
            }
        }
        .sheet(item: self.$viewModel.shareUrl,
               onDismiss: { self.viewModel.onShareDismiss() }) { item in
            ActivityViewController(activityItems: [item.url],
                                   thumbnail: item.thumbnail,
                                   title: item.url.lastPathComponent)
        }
        .sheet(isPresented: self.$viewModel.browseAllShow) {
            MemeTemplateBrowser(viewModel: self.viewModel)
        }
        .showSubscriptionView(self.$viewModel.monetizationShow,
                              onComplete: { self.viewModel.onMonetizationClose() })
        .alert(String(localized: "Saved to Photos"), isPresented: self.$viewModel.savedToPhotosAlertShow, actions: {
            Button("Ok", role: .cancel, action: {})
        }, message: {
            Text("The image has been saved to your photos.")
        })
        .alertPhotoLibraryPermission(isPresented: self.$viewModel.photosPermissionAlertShow)
        // Leaving Make is also the preview: no keyboard, no handles, just the
        // picture as it will be shared.
        .onChange(of: self.panel) { _, panel in
            guard panel == .share else { return }
            self.typing = false
            self.viewModel.select(captionId: nil)
        }
        // Tapping the picture puts the handles away; it should put the keyboard
        // away too, or the field goes on claiming a block that is no longer
        // chosen and the canvas stays squeezed under a keyboard nobody wants.
        .onChange(of: self.viewModel.selectedCaptionId) { _, selected in
            if selected == nil { self.typing = false }
        }
    }

    // MARK: - The canvas

    /// Takes every point the panels do not need. It is the thing being made:
    /// everything else on this screen is in service of it.
    private var canvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                .fill(ColorPalette.surface)
            if self.viewModel.isEmpty {
                VStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(ColorPalette.textTertiary)
                    Text("Pick a template below, or one of your own photos.")
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(DS.Spacing.md)
            } else {
                // Picking a block on the picture is the same request as tapping
                // the field: it means "I want to write here".
                MemeCanvasView(viewModel: self.viewModel,
                               showsPlaceholders: self.panel == .make,
                               onCaptionPicked: {
                                   self.panel = .make
                                   self.typing = true
                               })
                    .padding(DS.Spacing.xxs)
            }
            if self.viewModel.isLoadingTemplate {
                ZStack {
                    Color.black.opacity(0.25)
                    ProgressView().progressViewStyle(.circular).tint(.white)
                }
                .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(Text("The meme being made"))
    }

    private var panelPicker: some View {
        Picker("", selection: self.$panel) {
            ForEach(MemePanel.allCases) { panel in
                Text(panel.title).tag(panel)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(self.viewModel.isEmpty)
    }

    // MARK: - Make

    /// While the keyboard is up the panel shrinks to the field alone.
    ///
    /// Not a flourish: the keyboard takes about 340 points, and with the face
    /// chips, the swatches and the template strip all holding their ground the
    /// canvas was squeezed to a thumbnail — you could type, and not see what you
    /// were typing on. Everything below the field is a choice you make *before*
    /// or *after* writing, never during, so it can wait under the keyboard and
    /// give the picture its room back.
    private var makePanel: some View {
        VStack(spacing: DS.Spacing.sm) {
            self.captionField
            if !self.typing {
                self.faceStrip
                self.colourRow
                self.gallery
            }
        }
        .animation(DS.Motion.smooth, value: self.typing)
    }

    /// The field. It is the answer to the bug that started this: one text field,
    /// in a fixed place, that can always take focus — rather than a field over
    /// the canvas fighting a drag gesture for the same touch.
    private var captionField: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button {
                self.viewModel.addCaption()
                self.typing = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
            }
            .buttonStyle(.glass)
            .disabled(self.viewModel.isEmpty)
            .accessibilityLabel(Text("Add text"))

            TextField(self.hasSelection
                      ? String(localized: "Type the caption")
                      : String(localized: "Tap the words on the picture"),
                      text: self.viewModel.selectedCaptionText,
                      axis: .vertical)
                .lineLimit(1...3)
                .font(forCategory: .body1)
                .textInputAutocapitalization(self.viewModel.isUppercased ? .characters : .sentences)
                .focused(self.$typing)
                .submitLabel(.done)
                .disabled(!self.hasSelection)
                // A field is identified by its placeholder until something is
                // typed into it, and then by its contents — which makes it
                // unfindable from a test halfway through the thing being tested.
                .accessibilityIdentifier("memeCaptionField")
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .frame(minHeight: DS.Size.tapTarget)
                .background(ColorPalette.surface, in: .rect(cornerRadius: DS.Radius.control,
                                                            style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                        .strokeBorder(self.typing ? ColorPalette.accent : ColorPalette.separator,
                                      lineWidth: self.typing ? 2 : 1)
                }

            if self.hasSelection {
                Button(role: .destructive) {
                    self.typing = false
                    if let selected = self.viewModel.selectedCaptionId {
                        self.viewModel.removeCaption(id: selected)
                    }
                } label: {
                    Image(systemName: "trash")
                        .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Text("Delete text"))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(DS.Motion.quick, value: self.viewModel.selectedCaptionId)
    }

    private var hasSelection: Bool { self.viewModel.selectedCaptionId != nil }

    /// Each chip is drawn in the face it offers. A row of five names all set in
    /// the same type would say nothing about what is being chosen.
    private var faceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(ImageCanvasUtility.CaptionFace.allCases) { face in
                    let isSelected = face == self.viewModel.face
                    Button {
                        self.viewModel.face = face
                    } label: {
                        Text(face.title)
                            .font(Font(face.font(ofSize: 17)))
                            .foregroundStyle(isSelected ? .white : ColorPalette.textPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, DS.Spacing.sm)
                            .frame(height: DS.Size.tapTarget)
                            .background(isSelected ? ColorPalette.accent : ColorPalette.surface,
                                        in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                                    .strokeBorder(isSelected ? .clear : ColorPalette.separator, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(face.title))
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 1)
        }
        .disabled(self.viewModel.isEmpty)
    }

    private var colourRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(MemeTextColor.allCases) { color in
                Button {
                    self.viewModel.color = color
                } label: {
                    Circle()
                        .fill(color.swatch)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Circle().strokeBorder(color == self.viewModel.color
                                                  ? ColorPalette.accent : ColorPalette.separator,
                                                  lineWidth: color == self.viewModel.color ? 3 : 1)
                        }
                        .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.title))
                .accessibilityAddTraits(color == self.viewModel.color ? [.isButton, .isSelected] : .isButton)
            }

            Button {
                self.viewModel.isUppercased.toggle()
            } label: {
                Text(verbatim: "AA")
                    .font(.system(size: 15, weight: .black))
                    .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
            }
            .buttonStyle(.glass)
            .tint(self.viewModel.isUppercased ? ColorPalette.accent : ColorPalette.textSecondary)
            .accessibilityLabel(Text("All capitals"))
            .accessibilityAddTraits(self.viewModel.isUppercased ? [.isButton, .isSelected] : .isButton)

            Spacer(minLength: 0)
        }
        .disabled(self.viewModel.isEmpty)
    }

    // MARK: - The gallery

    @ViewBuilder private var gallery: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack {
                Text("Template")
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
                Spacer()
                // The strip holds a couple of dozen; the catalogue holds 174.
                // Anything past the well-known ones is found by name, not by
                // scrolling sideways past a hundred and fifty tiles.
                if self.viewModel.templates.count > Self.stripCount {
                    Button(String(localized: "See all")) {
                        self.typing = false
                        self.viewModel.browseAllShow = true
                    }
                    .font(forCategory: .caption1)
                    .tint(ColorPalette.accent)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    self.photoTile
                    ForEach(self.viewModel.templates.prefix(Self.stripCount)) { template in
                        Button {
                            self.typing = false
                            self.viewModel.select(template)
                        } label: {
                            self.templateTile(for: template)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(template.name))
                        .accessibilityAddTraits(
                            template.id == self.viewModel.selectedTemplateId ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var photoTile: some View {
        PhotosPicker(selection: self.$pickedPhoto, matching: .images, photoLibrary: .shared()) {
            VStack(spacing: DS.Spacing.xxs) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                        .fill(ColorPalette.surface)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                .frame(width: Self.tileSize, height: Self.tileSize)
                .overlay {
                    let isCurrent = self.viewModel.selectedTemplateId == nil && !self.viewModel.isEmpty
                    RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                        .strokeBorder(isCurrent ? ColorPalette.accent : ColorPalette.separator,
                                      lineWidth: isCurrent ? 3 : 1)
                }
                Text("Your photo")
                    .font(forCategory: .caption2)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: Self.tileSize)
        }
        .buttonStyle(.plain)
        .onChange(of: self.pickedPhoto) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let picked = try? await item.loadTransferable(type: PickedImage.self) {
                    self.viewModel.use(image: picked.uiImage)
                }
                self.pickedPhoto = nil
            }
        }
    }

    private func templateTile(for template: MemeTemplate) -> some View {
        let isSelected = template.id == self.viewModel.selectedTemplateId
        return VStack(spacing: DS.Spacing.xxs) {
            MemeTemplateThumbnail(url: template.thumbnailUrl, isSelected: isSelected)
                .frame(width: Self.tileSize, height: Self.tileSize)
            Text(template.name)
                .font(forCategory: .caption2)
                .foregroundStyle(isSelected ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: Self.tileSize)
        .contentShape(.rect)
    }

    private static let tileSize: CGFloat = 64
    /// How many fit in the strip before "See all" earns its place.
    private static let stripCount: Int = 24

    // MARK: - Share

    /// The three ways out, each with its name on it. They used to be a
    /// prominent button and two bare glyphs, which asked the user to guess what
    /// a downward arrow and a sheet of paper did to their meme.
    private var sharePanel: some View {
        VStack(spacing: DS.Spacing.xs) {
            if !self.viewModel.canExport {
                Text("Write something on the picture first.")
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Sharing leads, unlike every other tool in this app: a meme that
            // stays on the phone did not do its job.
            self.exitRow(title: String(localized: "Share"),
                         subtitle: String(localized: "Send it to someone"),
                         systemImage: "square.and.arrow.up",
                         isProminent: true) {
                self.viewModel.share()
            }
            self.exitRow(title: String(localized: "Save to Photos"),
                         subtitle: String(localized: "Keep it in your camera roll"),
                         systemImage: "square.and.arrow.down",
                         isProminent: false) {
                self.viewModel.saveToPhotos()
            }
            self.exitRow(title: String(localized: "To PDF"),
                         subtitle: String(localized: "Put it in a document"),
                         systemImage: "doc",
                         isProminent: false) {
                self.viewModel.createPdf()
            }
        }
        .disabled(!self.viewModel.canExport)
    }

    private func exitRow(title: String,
                         subtitle: String,
                         systemImage: String,
                         isProminent: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(forCategory: .button)
                    Text(subtitle)
                        .font(forCategory: .caption1)
                        .opacity(0.75)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: DS.Size.tapTarget)
            .padding(.horizontal, DS.Spacing.sm)
            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(subtitle))
        .memeExitStyle(isProminent: isProminent)
    }
}


fileprivate extension View {

    /// `buttonStyle` takes a concrete type, so the prominent and the plain row
    /// cannot be chosen with a ternary — the two branches have different types.
    /// A `ViewBuilder` can hold both.
    @ViewBuilder func memeExitStyle(isProminent: Bool) -> some View {
        if isProminent {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.glass)
        }
    }
}

/// The whole catalogue, found by name.
///
/// A grid rather than a longer strip: at 174 templates the question stops being
/// "which of these" and becomes "where is the one I am thinking of", and that is
/// a search field, not a scroll.
struct MemeTemplateBrowser: View {

    @ObservedObject var viewModel: MemeMakerViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var templates: [MemeTemplate] { self.viewModel.templates }

    private var shown: [MemeTemplate] {
        let needle = self.query.trimmingCharacters(in: .whitespaces)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !needle.isEmpty else { return self.templates }
        return self.templates.filter {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(needle)
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: DS.Spacing.sm)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: self.columns, spacing: DS.Spacing.md) {
                    ForEach(self.shown) { template in
                        Button {
                            self.viewModel.browseAllShow = false
                            self.viewModel.select(template)
                        } label: {
                            self.tile(for: template)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(template.name))
                    }
                }
                .padding(DS.Spacing.md)
            }
            .background(ColorPalette.background)
            .overlay {
                if self.templates.isEmpty {
                    ProgressView().progressViewStyle(.circular)
                } else if self.shown.isEmpty {
                    Text("No template with that name.")
                        .font(forCategory: .body1)
                        .foregroundStyle(ColorPalette.textSecondary)
                }
            }
            .searchable(text: self.$query, prompt: Text("Search templates"))
            .navigationTitle(Text("Templates"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { self.dismiss() }
                        .tint(ColorPalette.accent)
                }
            }
        }
    }

    private func tile(for template: MemeTemplate) -> some View {
        let isSelected = template.id == self.viewModel.selectedTemplateId
        return VStack(spacing: DS.Spacing.xxs) {
            MemeTemplateThumbnail(url: template.thumbnailUrl, isSelected: isSelected)
                .frame(height: Self.tileHeight)
            // Two lines, always: a name that needs one and a name that needs two
            // would otherwise give their rows different heights, and the pictures
            // would stop lining up across the grid.
            Text(template.name)
                .font(forCategory: .caption2)
                .foregroundStyle(ColorPalette.textSecondary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private static let tileHeight: CGFloat = 104
}

/// A template's picture, filling whatever frame the caller gives it.
///
/// Built inside out, and it took two goes. The obvious spelling — an
/// `AsyncImage` with `scaledToFill` and a frame fixing only the height — lets
/// the *image* decide the width: a 240-pixel thumbnail asked to fill a 96-point
/// box reports about 145 points, and a later `maxWidth: .infinity` widens but
/// never narrows. In a `LazyVGrid` of 96-point cells that drew every tile on
/// top of its neighbours.
///
/// The second go replaced the image with a square `Color.clear` and drew the
/// picture as an `overlay`, since overlays are sized by what they cover and
/// report nothing of their own. That fixed the overlap and broke the rows: a
/// lazy grid proposes **no** height, so `aspectRatio(1, contentMode: .fit)` had
/// nothing to fit into and resolved differently row by row — some cells came out
/// oblong and wide enough to eat two columns, leaving holes in the grid.
///
/// So this one carries no opinion about its own size at all. It is a plain
/// `Color`, which accepts any proposal, and **the caller states the frame** —
/// a square in the strip, a fixed height across the cell in the grid. Deciding
/// the size in one place is the whole fix.
struct MemeTemplateThumbnail: View {

    let url: URL?
    var isSelected: Bool = false

    var body: some View {
        ColorPalette.surface
            .overlay {
                AsyncImage(url: self.url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(ColorPalette.textTertiary)
                    default:
                        ProgressView().progressViewStyle(.circular)
                    }
                }
            }
            // Both: `clipped` cuts what `scaledToFill` pushes past the frame,
            // `clipShape` rounds what is left.
            .clipped()
            .clipShape(.rect(cornerRadius: DS.Radius.icon, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                    .strokeBorder(self.isSelected ? ColorPalette.accent : ColorPalette.separator,
                                  lineWidth: self.isSelected ? 3 : 1)
            }
    }
}

extension View {

    func showMemeMakerView(viewModel: MemeMakerViewModel) -> some View {
        self.modifier(MemeMakerView(viewModel: viewModel))
    }
}
