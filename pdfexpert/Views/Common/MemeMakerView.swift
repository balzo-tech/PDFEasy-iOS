//
//  MemeMakerView.swift
//  PdfExpert
//
//  Two fields and a picture. The preview is the real renderer running on a
//  downscaled copy, not an approximation drawn with SwiftUI text — so what is on
//  screen while typing is what lands in the share sheet.
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

struct MemeMakerEditorView: View {

    @ObservedObject var viewModel: MemeMakerViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focusedField: Field?
    @State private var pickedPhoto: PhotosPickerItem? = nil

    private enum Field { case top, bottom }

    private var isWideLayout: Bool { self.horizontalSizeClass == .regular }

    var body: some View {
        ToolScreen(title: String(localized: "Meme maker"),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        self.preview
                        self.gallery
                        self.fields
                        self.styleControls
                        self.actions
                    }
                    .padding(DS.Spacing.md)
                    .readableColumn()
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { self.focusedField = nil }
            }
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
        .sheet(isPresented: self.$viewModel.browseAllShow) {
            MemeTemplateBrowser(viewModel: self.viewModel)
        }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            if let image = self.viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                    .fill(ColorPalette.surface)
                    .overlay {
                        VStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(ColorPalette.textTertiary)
                            Text("Pick a template below, or one of your own photos.")
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(DS.Spacing.md)
                    }
            }
            if self.viewModel.isLoadingTemplate {
                ZStack {
                    Color.black.opacity(0.25)
                    ProgressView().progressViewStyle(.circular).tint(.white)
                }
                .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
            }
        }
        .frame(maxHeight: self.isWideLayout ? 460 : 300)
        .frame(minHeight: self.viewModel.isEmpty ? 180 : 0)
        .animation(DS.Motion.quick, value: self.viewModel.previewImage)
        .accessibilityLabel(Text("Preview of the meme"))
    }

    // MARK: - The gallery

    /// The templates, with the camera roll as the first tile. Horizontal rather
    /// than a grid: the list is curated and short, and a grid would push the
    /// caption fields below the fold on a phone — and the fields are the point.
    @ViewBuilder private var gallery: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
                        self.focusedField = nil
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
                            self.focusedField = nil
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
                    RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                        .strokeBorder(self.viewModel.selectedTemplateId == nil && !self.viewModel.isEmpty
                                      ? ColorPalette.accent : ColorPalette.separator,
                                      lineWidth: self.viewModel.selectedTemplateId == nil && !self.viewModel.isEmpty ? 3 : 1)
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

    private static let tileSize: CGFloat = 72
    /// How many fit in the strip before "See all" earns its place.
    private static let stripCount: Int = 24

    // MARK: - The words

    private var fields: some View {
        VStack(spacing: DS.Spacing.sm) {
            self.field(String(localized: "Top line"),
                       text: self.$viewModel.topText,
                       field: .top)
            self.field(String(localized: "Bottom line"),
                       text: self.$viewModel.bottomText,
                       field: .bottom)
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(1...3)
            .font(forCategory: .body1)
            .focused(self.$focusedField, equals: field)
            .submitLabel(.done)
            .textInputAutocapitalization(.sentences)
            .padding(DS.Spacing.sm)
            .frame(minHeight: DS.Size.tapTarget)
            .background(ColorPalette.surface, in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
    }

    // MARK: - How it looks

    private var styleControls: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Size")
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "textformat.size.smaller")
                        .foregroundStyle(ColorPalette.textTertiary)
                        .accessibilityHidden(true)
                    Slider(value: self.$viewModel.textScale, in: 0.05...0.20)
                        .accessibilityLabel(Text("Size"))
                    Image(systemName: "textformat.size.larger")
                        .foregroundStyle(ColorPalette.textTertiary)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Colour")
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(MemeTextColor.allCases) { color in
                        Button {
                            self.viewModel.color = color
                        } label: {
                            self.swatch(for: color)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(color.title))
                        .accessibilityAddTraits(color == self.viewModel.color ? [.isButton, .isSelected] : .isButton)
                    }
                    Spacer(minLength: 0)
                }
            }

            Toggle(isOn: self.$viewModel.isUppercased) {
                Text("All capitals")
                    .font(forCategory: .body1)
            }
        }
    }

    private func swatch(for color: MemeTextColor) -> some View {
        let isSelected = color == self.viewModel.color
        return Circle()
            .fill(color.swatch)
            .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
            .overlay {
                Circle()
                    .strokeBorder(isSelected ? ColorPalette.accent : ColorPalette.separator,
                                  lineWidth: isSelected ? 3 : 1)
            }
    }

    // MARK: - Ways out

    private var actions: some View {
        VStack(spacing: DS.Spacing.xs) {
            // Sharing leads, unlike every other tool in this app: a meme that
            // stays on the phone did not do its job.
            Button(action: { self.viewModel.share() }) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(forCategory: .button)
                    .frame(maxWidth: .infinity)
                    .frame(height: DS.Size.tapTarget)
            }
            .buttonStyle(.glassProminent)

            HStack(spacing: DS.Spacing.xs) {
                Button(action: { self.viewModel.saveToPhotos() }) {
                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                        .font(forCategory: .button)
                        .frame(maxWidth: .infinity)
                        .frame(height: DS.Size.tapTarget)
                }
                .buttonStyle(.glass)

                Button(action: { self.viewModel.createPdf() }) {
                    Label("To PDF", systemImage: "doc")
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
/// 72 x 72 in the strip, a fixed height across the cell in the grid. Deciding
/// the size in one place is the whole fix.
private struct MemeTemplateThumbnail: View {

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
