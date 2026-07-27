//
//  PdfCompressView.swift
//  PdfExpert
//
//  Compression as a before/after, not as a promise: the file is compressed while
//  the sheet is open, so the size and the preview on screen are the result the
//  user is about to save. Switching preset re-runs it.
//

import SwiftUI

struct PdfCompressView: ViewModifier {

    @ObservedObject var viewModel: PdfCompressViewModel

    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .compressOutcomes(viewModel: self.viewModel)
            .fullScreenCover(isPresented: self.$viewModel.editorShow) {
                PdfCompressEditorView(viewModel: self.viewModel)
            }
    }
}

/// The loader and the "it was saved" alert, without the editor itself: the
/// document editor pushes that screen and keeps only what belongs over the page.
struct PdfCompressOutcomes: ViewModifier {

    @ObservedObject var viewModel: PdfCompressViewModel

    func body(content: Content) -> some View {
        content
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncItem: self.$viewModel.asyncSave)
            .alert(String(localized: "Done"), isPresented: self.$viewModel.successAlertShow, actions: {
                Button("Ok", role: .cancel, action: {})
            }, message: {
                Text("A compressed copy has been saved to your archive.")
            })
    }
}

struct PdfCompressEditorView: View {

    @ObservedObject var viewModel: PdfCompressViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { self.horizontalSizeClass == .regular }

    var body: some View {
        ToolScreen(title: String(localized: "Compress PDF"),
                   confirm: ToolScreenAction(title: String(localized: "Save"),
                                             isEnabled: self.viewModel.canSave,
                                             action: { self.viewModel.save() }),
                   onCancel: { self.viewModel.cancel() }) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                VStack(spacing: DS.Spacing.lg) {
                    if self.isWideLayout { Spacer(minLength: 0) }
                    self.preview
                    self.sizeReadout
                    self.presetPicker
                    Spacer(minLength: 0)
                }
                .padding(DS.Spacing.md)
                .readableColumn()
            }
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
            }
            if self.viewModel.isCompressing {
                ZStack {
                    Color.black.opacity(0.25)
                    ProgressView(value: self.viewModel.progress)
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
            }
        }
        .frame(maxHeight: self.isWideLayout ? 400 : 280)
        .accessibilityLabel(Text("Preview of the compressed document"))
    }

    // MARK: - Numbers

    @ViewBuilder private var sizeReadout: some View {
        VStack(spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.sm) {
                Text(self.viewModel.originalByteCount.fileSizeText)
                    .font(forCategory: .body2)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .strikethrough(self.viewModel.result?.isSmaller == true)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorPalette.textTertiary)
                Text(self.compressedSizeText)
                    .font(forCategory: .title3)
                    .foregroundStyle(ColorPalette.textPrimary)
                    .contentTransition(.numericText())
            }
            Text(self.savingText)
                .font(forCategory: .caption1)
                .foregroundStyle(self.viewModel.result?.isSmaller == true
                                 ? ColorPalette.success
                                 : ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .animation(DS.Motion.quick, value: self.viewModel.result?.compressedByteCount)
    }

    private var compressedSizeText: String {
        guard let result = self.viewModel.result else { return "…" }
        return result.compressedByteCount.fileSizeText
    }

    private var savingText: String {
        if self.viewModel.isCompressing {
            return String(localized: "Compressing…")
        }
        guard let result = self.viewModel.result else { return "" }
        guard result.isSmaller else {
            // Being honest here matters more than showing a number: this document
            // is already as small as this tool can make it.
            return String(localized: "This document is already compressed as much as it can be.")
        }
        let percent = Int((result.savedFraction * 100).rounded())
        return String(localized: "\(percent)% smaller")
    }

    // MARK: - Presets

    private var presetPicker: some View {
        VStack(spacing: DS.Spacing.xs) {
            ForEach(CompressionPreset.allCases) { preset in
                Button {
                    self.viewModel.preset = preset
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.title)
                                .font(forCategory: .body2)
                                .foregroundStyle(ColorPalette.textPrimary)
                            Text(preset.subtitle)
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: preset == self.viewModel.preset
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(preset == self.viewModel.preset
                                             ? ColorPalette.accent
                                             : ColorPalette.textTertiary)
                    }
                    .padding(DS.Spacing.sm)
                    .frame(minHeight: DS.Size.tapTarget)
                    .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentCard(radius: DS.Radius.control)
                .accessibilityAddTraits(preset == self.viewModel.preset ? [.isButton, .isSelected] : .isButton)
            }
        }
        .disabled(self.viewModel.isCompressing)
    }
}

extension View {

    func showCompressView(viewModel: PdfCompressViewModel) -> some View {
        self.modifier(PdfCompressView(viewModel: viewModel))
    }

    func compressOutcomes(viewModel: PdfCompressViewModel) -> some View {
        self.modifier(PdfCompressOutcomes(viewModel: viewModel))
    }
}
