//
//  BackgroundRemovalView.swift
//  PdfExpert
//
//  The cut-out, shown against the backdrop the user is choosing rather than
//  described. The subject is lifted once when the photo arrives; every tap after
//  that only changes what is behind it, which is why the picker is a row of
//  swatches and not a form with an Apply button.
//
//  The chequerboard is not decoration: on a white page a transparent cut-out and
//  a white background look identical, and the user cannot tell which one they
//  are about to save.
//

import SwiftUI

struct BackgroundRemovalView: ViewModifier {

    @ObservedObject var viewModel: BackgroundRemovalViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: self.$viewModel.editorShow) {
                BackgroundRemovalEditorView(viewModel: self.viewModel)
            }
            // Outside the cover: an error here closes it, and an alert on a
            // screen that is leaving is an alert nobody sees.
            .showError(self.$viewModel.error)
    }
}

struct BackgroundRemovalEditorView: View {

    @ObservedObject var viewModel: BackgroundRemovalViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { self.horizontalSizeClass == .regular }

    var body: some View {
        ToolScreen(title: String(localized: "Remove background"),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                VStack(spacing: DS.Spacing.lg) {
                    if self.isWideLayout { Spacer(minLength: 0) }
                    self.preview
                    self.edgeSlider
                    self.stylePicker
                    self.actions
                    Spacer(minLength: 0)
                }
                .padding(DS.Spacing.md)
                .readableColumn()
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
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            if let image = self.viewModel.previewImage {
                // The chequerboard sits behind the *image*, not behind the frame
                // it is laid out in: stretched to the whole frame it reads as
                // transparent margins the photo does not have.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .background(CheckerboardView())
                    .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                    .fill(ColorPalette.surface)
            }
            if self.viewModel.isProcessing {
                ZStack {
                    Color.black.opacity(0.25)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
            }
        }
        .frame(maxHeight: self.isWideLayout ? 460 : 320)
        .animation(DS.Motion.quick, value: self.viewModel.previewImage)
        .accessibilityLabel(Text("Preview of the photo without its background"))
    }

    // MARK: - The edge

    /// One dial rather than a menu of named presets: the difference between a
    /// good cut-out and a haloed one is a few percent on this ramp, and it is
    /// visible in the preview while the thumb moves.
    private var edgeSlider: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack {
                Text("Edge")
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
                Spacer()
                #if DEBUG
                // The number, for tuning against real photographs.
                Text(String(format: "%.2f", self.viewModel.edgeStrength))
                    .font(forCategory: .caption2)
                    .monospacedDigit()
                    .foregroundStyle(ColorPalette.textTertiary)
                #endif
            }
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "aqi.medium")
                    .foregroundStyle(ColorPalette.textTertiary)
                    .accessibilityHidden(true)
                Slider(value: self.$viewModel.edgeStrength, in: 0...1)
                    .accessibilityLabel(Text("Edge"))
                    .accessibilityValue(Text("\(Int(self.viewModel.edgeStrength * 100))%"))
                Image(systemName: "scissors")
                    .foregroundStyle(ColorPalette.textTertiary)
                    .accessibilityHidden(true)
            }
            Text("Slide right if the old background still shows around the hair.")
                .font(forCategory: .caption2)
                .foregroundStyle(ColorPalette.textTertiary)
        }
        .disabled(!self.viewModel.canExport)
    }

    // MARK: - Backdrops

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Background")
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: DS.Spacing.sm) {
                ForEach(BackgroundRemovalStyle.allCases) { style in
                    Button {
                        self.viewModel.style = style
                    } label: {
                        self.swatch(for: style)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(style.title))
                    .accessibilityAddTraits(style == self.viewModel.style ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .disabled(!self.viewModel.canExport)
    }

    private func swatch(for style: BackgroundRemovalStyle) -> some View {
        let isSelected = style == self.viewModel.style
        return VStack(spacing: DS.Spacing.xxs) {
            ZStack {
                if style.isTransparent {
                    CheckerboardView(square: 6)
                } else if let color = style.cgColor {
                    Color(cgColor: color)
                }
            }
            .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
            .clipShape(.circle)
            .overlay {
                Circle()
                    .strokeBorder(isSelected ? ColorPalette.accent : ColorPalette.separator,
                                  lineWidth: isSelected ? 3 : 1)
            }
            Text(style.title)
                .font(forCategory: .caption2)
                .foregroundStyle(isSelected ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
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

/// The grey-and-white grid that stands for "nothing here".
struct CheckerboardView: View {

    var square: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(ColorPalette.surface))
            let columns = Int(ceil(size.width / self.square))
            let rows = Int(ceil(size.height / self.square))
            for row in 0..<max(rows, 1) {
                for column in 0..<max(columns, 1) where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * self.square,
                                      y: CGFloat(row) * self.square,
                                      width: self.square,
                                      height: self.square)
                    context.fill(Path(rect), with: .color(ColorPalette.background))
                }
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

extension View {

    func showBackgroundRemovalView(viewModel: BackgroundRemovalViewModel) -> some View {
        self.modifier(BackgroundRemovalView(viewModel: viewModel))
    }

    /// Saving needs permission to *add* to the library, and the only way back
    /// from a refusal is Settings — so the alert offers it rather than repeating
    /// the request iOS will not ask again. The title is the scanner's — it is
    /// the same permission — while the sentence under it is this tool's, since
    /// what is being saved here is one image, not a stack of pages.
    func alertPhotoLibraryPermission(isPresented: Binding<Bool>) -> some View {
        self.alert(String(localized: "Photos access is off"), isPresented: isPresented, actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("Allow adding photos to save the image to your library.")
        })
    }
}
