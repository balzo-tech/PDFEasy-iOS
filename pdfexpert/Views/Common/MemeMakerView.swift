//
//  MemeMakerView.swift
//  PdfExpert
//
//  A canvas, not a form.
//
//  The first version of this screen put two text fields under the picture and
//  locked one line to the top and one to the bottom. It was easy to build and
//  wrong to use: a meme is made by putting words *where the joke needs them*,
//  and every app that makes them lets you drag. So the picture is now the
//  biggest thing on screen, the words sit on it, and the controls are a single
//  strip that never competes with the canvas for room.
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

    @FocusState private var editing: UUID?
    @State private var pickedPhoto: PhotosPickerItem? = nil

    var body: some View {
        ToolScreen(title: String(localized: "Meme maker"),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                VStack(spacing: DS.Spacing.sm) {
                    self.canvas
                    self.textControls
                    self.gallery
                    self.actions
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
                .readableColumn()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { self.editing = nil }
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
    }

    // MARK: - The canvas

    /// Takes every point the controls do not need. It is the thing being made:
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
                MemeCanvasView(viewModel: self.viewModel, editing: self.$editing)
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

    // MARK: - The words

    /// One row, and it only offers what applies: the bin appears when a block is
    /// selected and not before.
    private var textControls: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button(action: {
                self.viewModel.addCaption()
                self.editing = self.viewModel.selectedCaptionId
            }) {
                Label("Text", systemImage: "plus")
                    .font(forCategory: .button)
                    .frame(height: DS.Size.tapTarget)
                    .padding(.horizontal, DS.Spacing.sm)
            }
            .buttonStyle(.glass)
            .disabled(self.viewModel.isEmpty)

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

            if let selected = self.viewModel.selectedCaptionId {
                Button(role: .destructive) {
                    self.editing = nil
                    self.viewModel.removeCaption(id: selected)
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
                        self.editing = nil
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
                            self.editing = nil
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

    // MARK: - Ways out

    private var actions: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Sharing leads, unlike every other tool in this app: a meme that
            // stays on the phone did not do its job.
            Button(action: {
                self.editing = nil
                self.viewModel.share()
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(forCategory: .button)
                    .frame(maxWidth: .infinity)
                    .frame(height: DS.Size.tapTarget)
            }
            .buttonStyle(.glassProminent)

            Button(action: {
                self.editing = nil
                self.viewModel.saveToPhotos()
            }) {
                Image(systemName: "square.and.arrow.down")
                    .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(Text("Save to Photos"))

            Button(action: {
                self.editing = nil
                self.viewModel.createPdf()
            }) {
                Image(systemName: "doc")
                    .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(Text("To PDF"))
        }
        .disabled(!self.viewModel.canExport)
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
