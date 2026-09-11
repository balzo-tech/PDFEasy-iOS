//
//  ImageEditorView.swift
//  PdfExpert
//
//  Turn, shape, tone — in that order down the screen, because that is the order
//  people work in: get it the right way up, decide what is in the frame, then
//  worry about how it looks.
//
//  Every control writes straight to the preview. There is no Apply button: the
//  picture is the form.
//

import SwiftUI

struct ImageEditorView: ViewModifier {

    @ObservedObject var viewModel: ImageEditorViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: self.$viewModel.editorShow) {
                ImageEditorEditorView(viewModel: self.viewModel)
            }
            .showError(self.$viewModel.error)
    }
}

struct ImageEditorEditorView: View {

    @ObservedObject var viewModel: ImageEditorViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { self.horizontalSizeClass == .regular }

    var body: some View {
        ToolScreen(title: String(localized: "Edit image"),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        self.preview
                        self.turnRow
                        self.shapePicker
                        self.dials
                        self.actions
                    }
                    .padding(DS.Spacing.md)
                    .readableColumn()
                }
            }
        }
        .sheet(item: self.$viewModel.shareUrl,
               onDismiss: { self.viewModel.onShareDismiss() }) { item in
            ActivityViewController(activityItems: [item.url],
                                   thumbnail: item.thumbnail,
                                   title: item.url.lastPathComponent)
        }
        .imageCropView(flow: self.viewModel.imageCropFlow)
        .showSubscriptionView(self.$viewModel.monetizationShow,
                              onComplete: { self.viewModel.onMonetizationClose() })
        .alert(String(localized: "Saved to Photos"), isPresented: self.$viewModel.savedToPhotosAlertShow, actions: {
            Button("Ok", role: .cancel, action: {})
        }, message: {
            Text("The image has been saved to your photos.")
        })
        .alertPhotoLibraryPermission(isPresented: self.$viewModel.photosPermissionAlertShow)
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
            }
        }
        .frame(maxHeight: self.isWideLayout ? 460 : 300)
        .animation(DS.Motion.quick, value: self.viewModel.previewImage)
        .accessibilityLabel(Text("Preview of the edited picture"))
    }

    // MARK: - Which way up

    private var turnRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            self.iconButton("rotate.left", label: String(localized: "Turn left")) {
                self.viewModel.turnAnticlockwise()
            }
            self.iconButton("rotate.right", label: String(localized: "Turn right")) {
                self.viewModel.turnClockwise()
            }
            self.iconButton("arrow.left.and.right.righttriangle.left.righttriangle.right",
                            label: String(localized: "Mirror")) {
                self.viewModel.mirror()
            }
            if self.viewModel.canCropFreely {
                self.iconButton("crop", label: String(localized: "Crop")) {
                    self.viewModel.cropFreely()
                }
            }
            self.iconButton("arrow.uturn.backward", label: String(localized: "Reset")) {
                self.viewModel.resetEdits()
            }
            .disabled(self.viewModel.isUntouched)
        }
    }

    private func iconButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: DS.Size.tapTarget)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(Text(label))
    }

    // MARK: - What is in the frame

    private var shapePicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // The quick shapes. `Crop` above is the one with handles; these are
            // for the case where the answer is just "square".
            Text("Shape")
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(ImageCropShape.allCases) { shape in
                        Button {
                            self.viewModel.shape = shape
                        } label: {
                            self.shapeTile(for: shape)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(shape.title))
                        .accessibilityAddTraits(shape == self.viewModel.shape ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func shapeTile(for shape: ImageCropShape) -> some View {
        let isSelected = shape == self.viewModel.shape
        return VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: shape.systemImage)
                .font(.system(size: 18, weight: .medium))
                .frame(width: DS.Size.toolIcon, height: DS.Size.toolIcon)
                .foregroundStyle(isSelected ? ColorPalette.accent : ColorPalette.textSecondary)
                .background(ColorPalette.surface, in: .rect(cornerRadius: DS.Radius.icon, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                        .strokeBorder(isSelected ? ColorPalette.accent : .clear, lineWidth: 2)
                }
            Text(shape.caption ?? shape.title)
                .font(forCategory: .caption2)
                .foregroundStyle(isSelected ? ColorPalette.textPrimary : ColorPalette.textSecondary)
        }
        .contentShape(.rect)
    }

    // MARK: - How it looks

    private var dials: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            self.dial(String(localized: "Brightness"),
                      value: self.$viewModel.brightness,
                      range: -0.4...0.4,
                      systemImage: "sun.max")
            self.dial(String(localized: "Contrast"),
                      value: self.$viewModel.contrast,
                      range: -0.5...0.5,
                      systemImage: "circle.lefthalf.filled")
            self.dial(String(localized: "Saturation"),
                      value: self.$viewModel.saturation,
                      range: -1.0...1.0,
                      systemImage: "drop")
        }
    }

    private func dial(_ title: String,
                      value: Binding<CGFloat>,
                      range: ClosedRange<CGFloat>,
                      systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textSecondary)
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(ColorPalette.textTertiary)
                    .accessibilityHidden(true)
                Slider(value: value, in: range)
                    .accessibilityLabel(Text(title))
            }
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

extension View {

    func showImageEditorView(viewModel: ImageEditorViewModel) -> some View {
        self.modifier(ImageEditorView(viewModel: viewModel))
    }
}
