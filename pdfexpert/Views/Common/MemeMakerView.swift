//
//  MemeMakerView.swift
//  PdfExpert
//
//  A picture, and as little else as the job allows.
//
//  Three goes at this screen. The first put two text fields under the image and
//  locked one line to the top and one to the bottom — easy to build, wrong to
//  use: a meme is made by putting words *where the joke needs them*. The second
//  made the picture draggable but piled the styling, the gallery and three ways
//  out into one strip under it. The third split that strip into two named panels
//  — better, and still six groups of controls competing with the one thing the
//  user came to look at.
//
//  So this one keeps **one** control permanently on screen, the field you type
//  in, and puts everything else behind three doors: `Picture`, `Text`, `Style`.
//  Each opens one panel, each panel answers one question, and none of them costs
//  the canvas a single point until it is asked for. What is left under the
//  picture is a field and a row of three — against a strip, a segmented control,
//  five face chips, four swatches and a gallery header, all at once.
//
//  The two ways out live in the navigation bar, where every other tool in this
//  app puts its finishing action, and both pass the paywall.
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

    /// The one place text is typed. A single flag, not a per-block one: there is
    /// a single field and it always writes into whichever block is selected.
    @FocusState private var typing: Bool

    var body: some View {
        ToolScreen(title: String(localized: "Meme maker"),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                VStack(spacing: DS.Spacing.sm) {
                    self.canvas
                    if !self.viewModel.isEmpty {
                        self.captionField
                        // Everything below the field is a choice made *before* or
                        // *after* writing, never during — so while the keyboard
                        // is up it stands down and gives the picture its room
                        // back. The keyboard takes some 340 points; without this
                        // the canvas was a thumbnail and you could type without
                        // seeing what you were typing on.
                        if !self.typing { self.toolRow }
                    }
                }
                .animation(DS.Motion.smooth, value: self.typing)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
                .readableColumn()
            }
            // Inside the content, so it reaches the navigation stack `ToolScreen`
            // builds. Applied outside it would have nowhere to land — which is
            // also true of the keyboard bar: hung on the cover rather than on
            // the stack, it never appeared at all, and the only "Done" on screen
            // was the keyboard's own return key.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { self.exportMenu }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { self.typing = false }
                }
            }
        }
        .sheet(isPresented: self.$viewModel.styleShow) {
            MemeStylePanel(viewModel: self.viewModel)
        }
        .sheet(isPresented: self.$viewModel.picturePickerShow) {
            MemePicturePicker(viewModel: self.viewModel)
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
        // Tapping the picture puts the handles away; it should put the keyboard
        // away too, or the field goes on claiming a block that is no longer
        // chosen and the canvas stays squeezed under a keyboard nobody wants.
        .onChange(of: self.viewModel.selectedCaptionId) { _, selected in
            if selected == nil { self.typing = false }
        }
    }

    // MARK: - The canvas

    /// Takes every point the controls do not need. It is the thing being made:
    /// everything else on this screen is in service of it.
    private var canvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                .fill(ColorPalette.surface)
            if self.viewModel.isEmpty {
                // The empty canvas is the first door, not a notice: there is
                // exactly one thing to do here and the whole rectangle does it.
                Button {
                    self.viewModel.picturePickerShow = true
                } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(ColorPalette.accent)
                        Text("Choose a picture")
                            .font(forCategory: .body1)
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            } else {
                // Picking a block on the picture is the same request as tapping
                // the field: it means "I want to write here".
                MemeCanvasView(viewModel: self.viewModel,
                               onCaptionPicked: { self.typing = true })
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
        // `contain` rather than a plain label: the blocks on the picture are
        // what a person navigates to, and a label on the container alone would
        // swallow them.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("The meme being made"))
    }

    // MARK: - Writing

    /// The field, and the only control that is always here. It is the answer to
    /// the bug that started all this: one text field, in a fixed place, that can
    /// always take focus — rather than a field over the canvas fighting a drag
    /// gesture for the same touch.
    private var captionField: some View {
        HStack(spacing: DS.Spacing.xs) {
            TextField(self.hasSelection
                      ? String(localized: "Type the caption")
                      : String(localized: "Tap the words on the picture"),
                      text: self.viewModel.selectedCaptionText,
                      axis: .vertical)
                .lineLimit(1...3)
                .font(forCategory: .body1)
                .textInputAutocapitalization(self.viewModel.isUppercased ? .characters : .sentences)
                .focused(self.$typing)
                // `.return`, not `.done`: the field takes up to three lines, so
                // its return key writes a line break rather than finishing
                // anything — and calling it "Done" put two buttons of that name
                // on screen, one of which wrote a newline into the caption.
                .submitLabel(.return)
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

    // MARK: - The three doors

    private var toolRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            self.door(title: String(localized: "Picture"),
                      systemImage: "photo.on.rectangle.angled",
                      accessibilityLabel: String(localized: "Choose a picture")) {
                self.typing = false
                self.viewModel.picturePickerShow = true
            }
            self.door(title: String(localized: "Text"),
                      systemImage: "plus.bubble",
                      accessibilityLabel: String(localized: "Add text")) {
                self.viewModel.addCaption()
                self.typing = true
            }
            self.door(title: String(localized: "Style"),
                      systemImage: "textformat",
                      accessibilityLabel: String(localized: "Style")) {
                self.typing = false
                // The panel sets the size and the alignment of *a block*, so it
                // needs one. Opened with nothing chosen it takes the first,
                // rather than showing controls that quietly do nothing.
                if self.viewModel.selectedCaptionId == nil {
                    self.viewModel.select(captionId: self.viewModel.captions.first?.id)
                }
                self.viewModel.styleShow = true
            }
        }
    }

    private func door(title: String,
                      systemImage: String,
                      accessibilityLabel: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(forCategory: .caption1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .contentShape(.rect)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    // MARK: - The two ways out

    /// Both doors in one menu, and both gated. A meme that stays on the phone
    /// did not do its job, so sharing is offered first.
    private var exportMenu: some View {
        Menu {
            Button {
                self.typing = false
                self.viewModel.share()
            } label: {
                Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
            }
            Button {
                self.typing = false
                self.viewModel.saveToPhotos()
            } label: {
                Label(String(localized: "Save to Photos"), systemImage: "square.and.arrow.down")
            }
        } label: {
            Text("Export").fontWeight(.semibold)
        }
        .disabled(!self.viewModel.canExport)
        .accessibilityLabel(Text("Export"))
    }
}

// MARK: - Style

/// Face, size, alignment and colour — the four answers to "how do the words
/// look", in the one place that asks the question.
///
/// A panel rather than a strip under the canvas. Each of these is set once and
/// then left alone for the rest of the sitting, and a control that is used once
/// has no business holding forty points of the picture's height for the other
/// nine tenths of the time.
private struct MemeStylePanel: View {

    @ObservedObject var viewModel: MemeMakerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    self.section(String(localized: "Font")) { self.faces }
                    self.section(String(localized: "Size")) { self.size }
                    self.section(String(localized: "Alignment")) { self.alignment }
                    self.section(String(localized: "Color")) { self.colours }
                }
                .padding(DS.Spacing.md)
                .readableColumn()
            }
            .background(ColorPalette.background)
            .navigationTitle(Text("Style"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { self.dismiss() }
                        .fontWeight(.semibold)
                        .tint(ColorPalette.accent)
                }
            }
        }
        .presentationDetents([.height(380), .large])
        .presentationDragIndicator(.visible)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textSecondary)
            content()
        }
    }

    /// Each chip is drawn in the face it offers. A row of five names all set in
    /// the same type would say nothing about what is being chosen.
    private var faces: some View {
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
    }

    /// Pinching the block on the canvas does the same thing, and is quicker once
    /// you know it is there. The slider is for everyone who does not.
    private var size: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(verbatim: "A").font(.system(size: 13, weight: .black))
            Slider(value: self.viewModel.selectedCaptionScale, in: 0.04...0.30)
                .tint(ColorPalette.accent)
                .accessibilityLabel(Text("Size"))
            Text(verbatim: "A").font(.system(size: 24, weight: .black))
        }
        .foregroundStyle(ColorPalette.textSecondary)
    }

    private var alignment: some View {
        Picker("", selection: self.viewModel.selectedCaptionAlignment) {
            ForEach(ImageCanvasUtility.CaptionAlignment.allCases) { alignment in
                Image(systemName: alignment.symbolName)
                    .accessibilityLabel(Text(alignment.title))
                    .tag(alignment)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var colours: some View {
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
    }
}

// MARK: - Choosing the picture

/// Every picture the tool can start from, in one grid: the catalogue, found by
/// name, with the camera roll at the top of it.
///
/// It replaced a strip of two dozen tiles under the canvas. At 174 templates the
/// question stops being "which of these" and becomes "where is the one I am
/// thinking of", and that is a search field, not a scroll — and the strip was
/// answering neither while charging the canvas a hundred points for the
/// privilege.
struct MemePicturePicker: View {

    @ObservedObject var viewModel: MemeMakerViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var pickedPhoto: PhotosPickerItem? = nil

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
                VStack(spacing: DS.Spacing.md) {
                    self.photoRow
                    LazyVGrid(columns: self.columns, spacing: DS.Spacing.md) {
                        ForEach(self.shown) { template in
                            Button {
                                self.viewModel.select(template)
                                self.dismiss()
                            } label: {
                                self.tile(for: template)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(template.name))
                        }
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
            .navigationTitle(Text("Picture"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { self.dismiss() }
                        .tint(ColorPalette.accent)
                }
            }
        }
    }

    /// The camera roll, first and full width: a picture of your own is a
    /// different kind of answer from a template, not the 175th template.
    private var photoRow: some View {
        PhotosPicker(selection: self.$pickedPhoto, matching: .images, photoLibrary: .shared()) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 17, weight: .semibold))
                Text("Your photo")
                    .font(forCategory: .button)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: DS.Size.tapTarget)
            .padding(.horizontal, DS.Spacing.sm)
            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .buttonStyle(.glass)
        .accessibilityLabel(Text("Your photo"))
        .onChange(of: self.pickedPhoto) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let picked = try? await item.loadTransferable(type: PickedImage.self) {
                    self.viewModel.use(image: picked.uiImage)
                    self.dismiss()
                }
                self.pickedPhoto = nil
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
/// a fixed height across the cell in the grid. Deciding the size in one place is
/// the whole fix.
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
