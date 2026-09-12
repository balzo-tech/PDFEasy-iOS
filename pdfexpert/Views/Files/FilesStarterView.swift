//
//  FilesStarterView.swift
//  PdfExpert
//
//  What the Files tab shows before there is anything to show.
//
//  It used to be a placeholder — a tray icon, a line of text and one button —
//  and it was where a third of every new install stopped. In the month to
//  2026-09-11, 1.164 people reached this screen and only 778 ever got as far as
//  the tool catalog in the next tab; of those who did, 94% picked a tool. The
//  catalog was never the problem, arriving at it was.
//
//  So the empty archive *is* the catalog now: the six ways to make a first
//  document, in the order people pick them, on the screen the app opens on.
//  Tapping one hands off to the Tools tab the same way the "New" menu always
//  has — that screen owns every tool flow, and a second implementation of them
//  here is exactly what `ToolCatalog` exists to prevent.
//

import SwiftUI
import Factory

struct FilesStarterView: View {

    /// The "convert from any file" guide belongs to the Files tab, which owns
    /// its presentation; this screen only asks for it.
    let onShowImportGuide: () -> Void

    @Injected(\.mainCoordinator) private var mainCoordinator

    /// The grid the Tools tab uses, so the tiles are the same size and the two
    /// screens read as one place rather than as a placeholder imitating one.
    private static let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 158, maximum: 260), spacing: DS.Spacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                self.header
                LazyVGrid(columns: Self.columns, spacing: DS.Spacing.sm) {
                    ForEach(ToolCatalog.starterTools) { tool in
                        ToolTileView(title: tool.title,
                                     subtitle: tool.subtitle,
                                     systemImage: tool.systemImage,
                                     tint: tool.tint) {
                            self.start(tool)
                        }
                    }
                }
                self.footer
            }
            .padding(DS.Spacing.md)
            // The tab bar floats over the content rather than inset beside it,
            // and with no "New" button below there is no safe-area inset left to
            // push the last link clear of it.
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text("Make your first PDF")
                .font(forCategory: .title2)
                .foregroundStyle(ColorPalette.textPrimary)
            Text("Pick a starting point. Everything you make is saved here.")
                .font(forCategory: .body2)
                .foregroundStyle(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The two ways out of the six tiles: the guide for a file format none of
    /// them names, and the rest of the catalog.
    private var footer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Button("Convert from any file", action: self.onShowImportGuide)
                .font(forCategory: .linkText)
            Button("Browse all \(ToolCatalog.allTools.count) tools") {
                self.mainCoordinator.tab = .tools
            }
            .font(forCategory: .linkText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    /// Same hand-off as the "New" menu: the Tools tab runs the flow, wherever
    /// the request came from. On an iPad it also selects the tool, so the detail
    /// column describes what just opened.
    private func start(_ tool: PdfTool) {
        self.mainCoordinator.runTool(tool.action)
    }
}

#Preview {
    NavigationStack {
        FilesStarterView(onShowImportGuide: {})
            .background(ColorPalette.background)
            .navigationTitle("Files")
    }
}
