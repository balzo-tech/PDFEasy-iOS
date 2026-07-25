//
//  QuickActionsWidget.swift
//  PdfProWidget
//
//  A launcher for the handful of tools people use on the move. The identifiers
//  match `HomeAction.identifier` in the app, which is what the tool deeplink
//  resolves.
//

import WidgetKit
import SwiftUI

struct QuickAction: Identifiable {

    let id: String
    let title: LocalizedStringResource
    let systemImage: String
    let tint: Color

    static let all: [QuickAction] = [
        QuickAction(id: "scan", title: "Scan", systemImage: "doc.viewfinder", tint: .blue),
        QuickAction(id: "imageToPdf", title: "Photos", systemImage: "photo.on.rectangle.angled", tint: .indigo),
        QuickAction(id: "merge", title: "Merge", systemImage: "arrow.trianglehead.merge", tint: .purple),
        QuickAction(id: "sign", title: "Sign", systemImage: "signature", tint: .orange)
    ]
}

struct QuickActionsEntry: TimelineEntry {
    let date: Date
}

struct QuickActionsProvider: TimelineProvider {

    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        // Static content: one entry, never expires.
        completion(Timeline(entries: [QuickActionsEntry(date: Date())], policy: .never))
    }
}

struct QuickActionsWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickActionsWidget", provider: QuickActionsProvider()) { _ in
            QuickActionsView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick actions")
        .description("Start a scan or a conversion straight from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickActionsView: View {

    @Environment(\.widgetFamily) private var family

    private var actions: [QuickAction] {
        self.family == .systemSmall ? Array(QuickAction.all.prefix(2)) : QuickAction.all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: self.family == .systemSmall ? 10 : 12) {
                ForEach(self.actions) { action in
                    Link(destination: WidgetLinks.tool(action.id) ?? URL(string: "https://balzo.eu")!) {
                        VStack(spacing: 5) {
                            Image(systemName: action.systemImage)
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(action.tint)
                                .frame(width: 42, height: 42)
                                .background(action.tint.opacity(0.15), in: .circle)
                            Text(action.title)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
