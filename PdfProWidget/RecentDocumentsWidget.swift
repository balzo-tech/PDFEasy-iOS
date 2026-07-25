//
//  RecentDocumentsWidget.swift
//  PdfProWidget
//
//  The documents the user last saved, straight from the snapshot the app writes
//  into the shared app group.
//

import WidgetKit
import SwiftUI

struct RecentDocumentsEntry: TimelineEntry {
    let date: Date
    let documents: [SharedDocument]
}

struct RecentDocumentsProvider: TimelineProvider {

    func placeholder(in context: Context) -> RecentDocumentsEntry {
        RecentDocumentsEntry(date: Date(), documents: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentDocumentsEntry) -> Void) {
        completion(RecentDocumentsEntry(date: Date(), documents: SharedDocumentStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentDocumentsEntry>) -> Void) {
        let entry = RecentDocumentsEntry(date: Date(), documents: SharedDocumentStore.load())
        // The app reloads the timeline whenever the archive changes; this is just
        // the fallback so relative dates do not go stale.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60))))
    }
}

struct RecentDocumentsWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecentDocumentsWidget", provider: RecentDocumentsProvider()) { entry in
            RecentDocumentsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent documents")
        .description("Your latest PDFs, one tap away.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RecentDocumentsView: View {

    @Environment(\.widgetFamily) private var family

    let entry: RecentDocumentsEntry

    private var visibleDocuments: [SharedDocument] {
        switch self.family {
        case .systemSmall: return Array(self.entry.documents.prefix(1))
        case .systemLarge: return Array(self.entry.documents.prefix(6))
        default: return Array(self.entry.documents.prefix(3))
        }
    }

    var body: some View {
        if self.entry.documents.isEmpty {
            self.emptyView
        } else if self.family == .systemSmall {
            self.singleDocumentView
        } else {
            self.gridView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(WidgetPalette.accent)
            Text("No documents yet")
                .font(.caption)
                .foregroundStyle(WidgetPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(WidgetLinks.files)
    }

    @ViewBuilder private var singleDocumentView: some View {
        if let document = self.visibleDocuments.first {
            VStack(alignment: .leading, spacing: 6) {
                DocumentThumbnailView(document: document)
                    .frame(maxWidth: .infinity)
                Text(document.displayName)
                    .font(.caption).fontWeight(.medium)
                    .lineLimit(1)
                Text("\(document.pageCount) pages")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.textSecondary)
            }
            .widgetURL(WidgetLinks.document(document.id))
        }
    }

    private var gridView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10),
                            count: self.family == .systemLarge ? 3 : 3)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.caption).fontWeight(.semibold)
                Spacer()
                Image(systemName: "folder")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.accent)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(self.visibleDocuments) { document in
                    Link(destination: WidgetLinks.document(document.id) ?? URL(string: "https://balzo.eu")!) {
                        VStack(alignment: .leading, spacing: 3) {
                            DocumentThumbnailView(document: document)
                            Text(document.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Page preview with a neutral placeholder, clipped to a card.
struct DocumentThumbnailView: View {

    let document: SharedDocument

    var body: some View {
        ZStack {
            if let image = SharedDocumentStore.thumbnail(for: self.document) {
                Color.clear.overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            } else {
                WidgetPalette.placeholder
                Image(systemName: "doc.text")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(WidgetPalette.textSecondary)
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 6, style: .continuous))
    }
}
