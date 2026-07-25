//
//  FilesFilterBar.swift
//  PdfExpert
//
//  The row of filter chips above the archive: one folder at a time, any number
//  of tags on top of it. It only appears once the user has actually created
//  something to filter by — an archive with no folders and no tags shows no bar.
//

import SwiftUI

/// Capsule chip. Selected chips carry the folder's or tag's own colour, so the
/// bar reads as a legend of the archive rather than as generic controls.
struct FilterChip: View {

    let title: String
    var systemImage: String? = nil
    var tint: Color = ColorPalette.accent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: DS.Spacing.xxs) {
                if let systemImage = self.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        // The symbol keeps the folder's or tag's colour even when
                        // the chip is off: that colour is how the bar is read.
                        .foregroundStyle(self.tint)
                }
                Text(self.title)
                    .font(forCategory: .caption1)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(self.isSelected ? self.tint : ColorPalette.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .frame(height: 32)
            .background {
                Capsule()
                    .fill(self.isSelected ? self.tint.opacity(0.16) : ColorPalette.surface)
                    .overlay {
                        Capsule().strokeBorder(self.isSelected ? self.tint.opacity(0.45) : ColorPalette.separator,
                                               lineWidth: 1)
                    }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(self.isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct FilesFilterBar: View {

    let folders: [Folder]
    let tags: [Tag]
    @Binding var folderFilter: FolderFilter
    @Binding var selectedTagIds: Set<String>
    let onManage: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Spacing.xs) {
                FilterChip(title: String(localized: "All"),
                           isSelected: self.folderFilter == .all) {
                    self.select(.all)
                }

                ForEach(self.folders) { folder in
                    FilterChip(title: folder.name,
                               systemImage: "folder.fill",
                               tint: folder.color.color,
                               isSelected: self.folderFilter == .folder(id: folder.id)) {
                        self.select(.folder(id: folder.id))
                    }
                }

                if !self.folders.isEmpty {
                    FilterChip(title: String(localized: "Unfiled"),
                               systemImage: "tray",
                               isSelected: self.folderFilter == .unfiled) {
                        self.select(.unfiled)
                    }
                }

                if !self.tags.isEmpty {
                    Divider().frame(height: 20)
                    ForEach(self.tags) { tag in
                        FilterChip(title: tag.name,
                                   systemImage: "circle.fill",
                                   tint: tag.color.color,
                                   isSelected: self.selectedTagIds.contains(tag.id)) {
                            withAnimation(DS.Motion.quick) { self.toggle(tag) }
                        }
                    }
                }

                Button(action: self.onManage) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorPalette.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Capsule().fill(ColorPalette.surface))
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Manage folders and tags"))
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
        }
        .scrollIndicators(.hidden)
    }

    private func select(_ filter: FolderFilter) {
        withAnimation(DS.Motion.quick) {
            // Tapping the active folder again clears it, the way a toggle would.
            self.folderFilter = self.folderFilter == filter ? .all : filter
        }
    }

    private func toggle(_ tag: Tag) {
        if self.selectedTagIds.contains(tag.id) {
            self.selectedTagIds.remove(tag.id)
        } else {
            self.selectedTagIds.insert(tag.id)
        }
    }
}

#Preview("Filter bar") {
    FilesFilterBar(folders: [Folder(name: "Invoices", color: .orange),
                             Folder(name: "Contracts", color: .green)],
                   tags: [Tag(name: "Urgent", color: .red), Tag(name: "2026", color: .purple)],
                   folderFilter: .constant(.all),
                   selectedTagIds: .constant([]),
                   onManage: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
}
