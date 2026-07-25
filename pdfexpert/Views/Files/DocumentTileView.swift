//
//  DocumentTileView.swift
//  PdfExpert
//
//  How a saved document is presented in the Files tab, as a grid card or as a
//  list row.
//

import SwiftUI

/// Grid card: the page itself is the affordance, metadata sits underneath.
struct DocumentCardView: View {

    let pdf: Pdf
    let onOpen: () -> Void

    var body: some View {
        Button(action: self.onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                DocumentThumbnail(pdf: self.pdf)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 6, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if self.pdf.password != nil {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(.black.opacity(0.45), in: .circle)
                                .padding(4)
                        }
                    }
                    .padding(DS.Spacing.xxs)

                // Fixed-height caption block so cards in a row line up even when
                // one filename wraps to two lines.
                VStack(alignment: .leading, spacing: 1) {
                    Text(self.pdf.displayName)
                        .font(forCategory: .caption1)
                        .fontWeight(.medium)
                        .foregroundStyle(ColorPalette.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    HStack(spacing: DS.Spacing.xxs) {
                        Text(self.pdf.pageCountText)
                            .font(forCategory: .caption2)
                            .foregroundStyle(ColorPalette.textSecondary)
                            .lineLimit(1)
                        TagDotsView(tags: self.pdf.tags)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.bottom, DS.Spacing.xs)
            }
            .contentShape(.rect(cornerRadius: DS.Radius.tile, style: .continuous))
        }
        .buttonStyle(PressableTileButtonStyle())
        .accessibilityLabel(Text(self.pdf.filename))
        .accessibilityValue(Text(self.pdf.metadataText))
    }
}

/// List row: denser, for when the user wants to scan many filenames at once.
struct DocumentRowView: View {

    let pdf: Pdf
    let onOpen: () -> Void

    var body: some View {
        Button(action: self.onOpen) {
            HStack(spacing: DS.Spacing.sm) {
                DocumentThumbnail(pdf: self.pdf)
                    .frame(width: 46, height: 60)
                    .clipShape(.rect(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(self.pdf.displayName)
                        .font(forCategory: .body3)
                        .foregroundStyle(ColorPalette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: DS.Spacing.xxs) {
                        if self.pdf.password != nil {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ColorPalette.textSecondary)
                        }
                        if let folder = self.pdf.folder {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(folder.color.color)
                            Text(folder.name)
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textSecondary)
                                .lineLimit(1)
                            Text("·")
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textTertiary)
                        }
                        Text(self.pdf.metadataText)
                            .font(forCategory: .caption1)
                            .foregroundStyle(ColorPalette.textSecondary)
                            .lineLimit(1)
                        TagDotsView(tags: self.pdf.tags)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorPalette.textTertiary)
            }
            .padding(DS.Spacing.sm)
            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .buttonStyle(PressableTileButtonStyle(radius: DS.Radius.control))
        .accessibilityLabel(Text(self.pdf.filename))
        .accessibilityValue(Text(self.pdf.metadataText))
    }
}

/// The document's tags as coloured dots: on a card there is no room for their
/// names, and the colours are enough to recognise a pile at a glance.
struct TagDotsView: View {

    let tags: [Tag]
    var maxCount: Int = 3

    var body: some View {
        if !self.tags.isEmpty {
            HStack(spacing: 2) {
                ForEach(self.tags.prefix(self.maxCount)) { tag in
                    Circle()
                        .fill(tag.color.color)
                        .frame(width: 6, height: 6)
                }
                if self.tags.count > self.maxCount {
                    Text(verbatim: "+\(self.tags.count - self.maxCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ColorPalette.textTertiary)
                }
            }
            .accessibilityLabel(Text(self.tags.map(\.name).joined(separator: ", ")))
        }
    }
}

/// Page preview, or a neutral placeholder when the document has no thumbnail.
struct DocumentThumbnail: View {

    let pdf: Pdf

    var body: some View {
        Group {
            if let thumbnail = self.pdf.thumbnail {
                Color.clear.overlay {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                }
            } else {
                ZStack {
                    ColorPalette.surfaceElevated
                    Image(systemName: "doc.text")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(ColorPalette.textTertiary)
                }
            }
        }
        .clipped()
    }
}

extension Pdf {

    /// Filename without the extension: every document here is a PDF, so the
    /// suffix is noise that pushes real words out of the line.
    var displayName: String {
        let name = self.filename
        guard name.lowercased().hasSuffix(".pdf") else { return name }
        return String(name.dropLast(4))
    }

    /// "12 pages · Yesterday" — the two things worth knowing at a glance.
    var metadataText: String {
        let pages = String(localized: "\(self.pageCount) pages")
        let date = self.creationDate.formatted(.relative(presentation: .named))
        return "\(pages) · \(date)"
    }
}
