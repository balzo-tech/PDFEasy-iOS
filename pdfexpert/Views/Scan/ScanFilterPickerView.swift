//
//  ScanFilterPickerView.swift
//  PdfExpert
//
//  Picks the look of a scanned page, showing the actual page under each filter
//  rather than four words.
//
//  The thumbnails are rendered through the same pipeline the final PDF uses, so
//  what the row shows is what the document will contain — including the odd case
//  where "black & white" turns a faint pencil note into nothing at all, which is
//  worth finding out here rather than after saving.
//

import SwiftUI

struct ScanFilterPickerView: View {

    @Binding var selection: ScanFilter
    /// The page previewed under each filter. `nil` before anything is captured,
    /// in which case the row falls back to plain labels.
    let page: ScannedPage?
    @ObservedObject var viewModel: DocumentScanViewModel
    var appliesToAllTitle: String? = nil
    var onApplyToAll: ((ScanFilter) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Filters")
                .font(forCategory: .title3)
                .foregroundStyle(ColorPalette.textPrimary)
                .padding(.horizontal, DS.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(ScanFilter.allCases) { filter in
                        Button {
                            withAnimation(DS.Motion.quick) { self.selection = filter }
                        } label: {
                            self.option(for: filter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
            }

            if let title = self.appliesToAllTitle, let onApplyToAll = self.onApplyToAll,
               self.viewModel.pages.count > 1 {
                Button {
                    onApplyToAll(self.selection)
                    self.dismiss()
                } label: {
                    Label(title, systemImage: "square.on.square")
                        .font(forCategory: .body2)
                }
                .padding(.horizontal, DS.Spacing.md)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorPalette.background)
    }

    @ViewBuilder private func option(for filter: ScanFilter) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Group {
                if let page = self.page {
                    ScanPageThumbnail(page: Self.variant(of: page, filter: filter),
                                      viewModel: self.viewModel)
                } else {
                    ZStack {
                        ColorPalette.surfaceElevated
                        Image(systemName: filter.systemImage)
                            .font(.system(size: 20))
                            .foregroundStyle(ColorPalette.textSecondary)
                    }
                }
            }
            .frame(width: 76, height: 96)
            .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                    .strokeBorder(self.selection == filter ? ColorPalette.accent : ColorPalette.separator,
                                  lineWidth: self.selection == filter ? 2.5 : 1)
            }

            Text(filter.title)
                .font(forCategory: .caption1)
                .foregroundStyle(self.selection == filter ? ColorPalette.accent : ColorPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 84)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(filter.title))
        .accessibilityAddTraits(self.selection == filter ? [.isButton, .isSelected] : .isButton)
    }

    /// The same page under a different filter — what each thumbnail renders.
    private static func variant(of page: ScannedPage, filter: ScanFilter) -> ScannedPage {
        var copy = page
        copy.filter = filter
        return copy
    }
}
