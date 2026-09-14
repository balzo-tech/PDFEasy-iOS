//
//  ImageCompressView.swift
//  PdfExpert
//
//  Compression as a before/after, like `PdfCompressView`, with one difference
//  that changes the whole screen: there are several pictures, so the number that
//  matters is the total. The rows underneath are the receipt — which photograph
//  gave up what — and the two dials above are the only decision on the screen.
//
//  Size before quality, top to bottom, because that is the order of their effect:
//  resolution is what shrinks a photograph, quality is what is left to trade once
//  the resolution is settled.
//

import SwiftUI

struct ImageCompressView: ViewModifier {

    @ObservedObject var viewModel: ImageCompressViewModel

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: self.$viewModel.editorShow) {
                ImageCompressEditorView(viewModel: self.viewModel)
            }
            .showError(self.$viewModel.error)
    }
}

struct ImageCompressEditorView: View {

    @ObservedObject var viewModel: ImageCompressViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { self.horizontalSizeClass == .regular }

    var body: some View {
        ToolScreen(title: String(localized: "Compress images"),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) {
                            self.sizeReadout
                            self.sizePicker
                            self.qualityPicker
                            self.imageList
                            self.privacyNote
                        }
                        .padding(DS.Spacing.md)
                        .readableColumn()
                    }
                    self.actions
                }
            }
        }
        .sheet(item: self.$viewModel.shareUrls,
               onDismiss: { self.viewModel.onShareDismiss() }) { item in
            ActivityViewController(activityItems: item.urls,
                                   thumbnail: item.thumbnail,
                                   title: self.shareTitle(for: item.urls.count))
        }
        .alert(String(localized: "Saved to Photos"), isPresented: self.$viewModel.savedToPhotosAlertShow, actions: {
            Button("Ok", role: .cancel, action: {})
        }, message: {
            Text("The compressed images have been saved to your photos.")
        })
        .alertPhotoLibraryPermission(isPresented: self.$viewModel.photosPermissionAlertShow)
    }

    // MARK: - The number the decision is made on

    private var sizeReadout: some View {
        VStack(spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.sm) {
                Text(self.viewModel.originalByteCount.fileSizeText)
                    .font(forCategory: .body2)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .strikethrough(self.viewModel.isSmaller)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorPalette.textTertiary)
                Text(self.viewModel.compressedByteCount.fileSizeText)
                    .font(forCategory: .title3)
                    .foregroundStyle(ColorPalette.textPrimary)
                    .contentTransition(.numericText())
            }
            Text(self.savingText)
                .font(forCategory: .caption1)
                .foregroundStyle(self.viewModel.isSmaller && !self.viewModel.isCompressing
                                 ? ColorPalette.success
                                 : ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(DS.Motion.quick, value: self.viewModel.compressedByteCount)
    }

    private var savingText: String {
        if self.viewModel.isCompressing {
            return String(localized: "Compressing…")
        }
        guard self.viewModel.isSmaller else {
            // Honest rather than encouraging: these pictures are already as small
            // as this tool can make them, and saving a copy would gain nothing.
            return String(localized: "These images are already compressed as much as they can be.")
        }
        let percent = Int((self.viewModel.savedFraction * 100).rounded())
        let count = self.viewModel.items.count
        // One picture has no "across N" to say, and that sentence cannot be put
        // in the singular without a substitution inside the string catalog. The
        // line "Compress PDF" already uses says exactly this, in every language.
        guard count > 1 else { return String(localized: "\(percent)% smaller") }
        return String(localized: "\(percent)% smaller, across \(count) images")
    }

    // MARK: - The two dials

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Size")
                .font(forCategory: .body2)
                .foregroundStyle(ColorPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: DS.Spacing.xs) {
                ForEach(ImageCompressionSize.allCases) { size in
                    Button {
                        self.viewModel.size = size
                    } label: {
                        VStack(spacing: 2) {
                            Text(size.title)
                                .font(forCategory: .body2)
                                .foregroundStyle(size == self.viewModel.size
                                                 ? ColorPalette.accent
                                                 : ColorPalette.textPrimary)
                            Text(size.caption)
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textSecondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DS.Size.tapTarget)
                        .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentCard(radius: DS.Radius.control)
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                            .strokeBorder(size == self.viewModel.size
                                          ? ColorPalette.accent
                                          : .clear,
                                          lineWidth: 2)
                    }
                    .accessibilityAddTraits(size == self.viewModel.size ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .disabled(self.viewModel.isCompressing)
    }

    private var qualityPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Quality")
                .font(forCategory: .body2)
                .foregroundStyle(ColorPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(ImageCompressionQuality.allCases) { quality in
                Button {
                    self.viewModel.quality = quality
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quality.title)
                                .font(forCategory: .body2)
                                .foregroundStyle(ColorPalette.textPrimary)
                            Text(quality.subtitle)
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: quality == self.viewModel.quality
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(quality == self.viewModel.quality
                                             ? ColorPalette.accent
                                             : ColorPalette.textTertiary)
                    }
                    .padding(DS.Spacing.sm)
                    .frame(minHeight: DS.Size.tapTarget)
                    .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentCard(radius: DS.Radius.control)
                .accessibilityAddTraits(quality == self.viewModel.quality ? [.isButton, .isSelected] : .isButton)
            }
        }
        .disabled(self.viewModel.isCompressing)
    }

    // MARK: - The receipt

    private var imageList: some View {
        LazyVStack(spacing: DS.Spacing.xs) {
            ForEach(self.viewModel.items) { item in
                HStack(spacing: DS.Spacing.sm) {
                    self.thumbnail(for: item)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.source.filename)
                            .font(forCategory: .body2)
                            .foregroundStyle(ColorPalette.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(self.rowText(for: item))
                            .font(forCategory: .caption1)
                            .foregroundStyle(ColorPalette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if item.outcome == nil, !item.didFail {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
                .padding(DS.Spacing.sm)
                .contentCard(radius: DS.Radius.control)
            }
        }
    }

    private func thumbnail(for item: ImageCompressItem) -> some View {
        // A fixed square decided here, not by the picture: a thumbnail that sets
        // its own width is the measurement trap in `swiftui-presentation-traps`,
        // and in a list of fifty it would make every row a different shape.
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                .fill(ColorPalette.surface)
            if let thumbnail = item.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
    }

    /// "2,4 MB → 480 KB · 1600 × 1200" — and, while it is running, the original
    /// weight on its own rather than a number from the previous setting.
    private func rowText(for item: ImageCompressItem) -> String {
        guard let outcome = item.outcome else {
            guard item.didFail else { return item.originalByteCount.fileSizeText }
            return String(localized: "\(item.originalByteCount.fileSizeText) · could not be compressed")
        }
        let pixels = "\(Int(outcome.pixelSize.width)) × \(Int(outcome.pixelSize.height))"
        guard outcome.isSmaller else {
            return String(localized: "\(item.originalByteCount.fileSizeText) · already small · \(pixels)")
        }
        return "\(item.originalByteCount.fileSizeText) → \(outcome.byteCount.fileSizeText) · \(pixels)"
    }

    private var privacyNote: some View {
        Text("Location and camera details are removed from the compressed copies. The originals are left untouched.")
            .font(forCategory: .caption1)
            .foregroundStyle(ColorPalette.textTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    // MARK: - The way out

    private var actions: some View {
        HStack(spacing: DS.Spacing.sm) {
            self.actionButton(title: String(localized: "Save to Photos"),
                              systemImage: "square.and.arrow.down") {
                self.viewModel.saveToPhotos()
            }
            self.actionButton(title: String(localized: "Share"),
                              systemImage: "square.and.arrow.up") {
                self.viewModel.share()
            }
        }
        .padding(DS.Spacing.md)
        .readableColumn()
        .disabled(!self.viewModel.canExport)
        .background(ColorPalette.background)
    }

    private func actionButton(title: String,
                              systemImage: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                Text(title)
                    .font(forCategory: .body2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(ColorPalette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: DS.Size.tapTarget)
            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentCard(radius: DS.Radius.control)
    }

    private func shareTitle(for count: Int) -> String {
        String(localized: "\(count) compressed images")
    }
}

extension View {

    func showImageCompressView(viewModel: ImageCompressViewModel) -> some View {
        self.modifier(ImageCompressView(viewModel: viewModel))
    }
}
