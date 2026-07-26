//
//  GlobalSearchView.swift
//  PdfExpert
//
//  One search field over everything the app holds: the saved documents (by
//  filename and indexed page text) and the tool catalog. It backs the tab
//  carrying the system's `.search` role.
//

import SwiftUI
import Factory

struct GlobalSearchView: View {

    // Its own archive on purpose: this screen drives `searchText`, and sharing
    // the instance with the Files grid would leave that grid filtered by
    // whatever was last typed here.
    @InjectedObject(\.archiveViewModel) var viewModel
    @Injected(\.mainCoordinator) private var mainCoordinator

    /// Bound by the split shell, where a result previews in the detail column
    /// instead of opening the editor. See `FilesView`.
    var selection: Binding<String?>? = nil

    @State private var query: String = ""

    private var trimmedQuery: String {
        self.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingTools: [PdfTool] {
        guard !self.trimmedQuery.isEmpty else { return [] }
        return ToolCatalog.allTools.filter { $0.matches(query: self.trimmedQuery) }
    }

    private var matchingDocuments: [Pdf] {
        guard !self.trimmedQuery.isEmpty,
              case .data(let items) = self.viewModel.asyncItems.status else { return [] }
        return self.viewModel.filteredItems(items)
    }

    var body: some View {
        ScrollView {
            if self.trimmedQuery.isEmpty {
                self.suggestionsView
            } else if self.matchingTools.isEmpty && self.matchingDocuments.isEmpty {
                ContentUnavailableView.search(text: self.trimmedQuery)
                    .padding(.top, DS.Spacing.xxl)
            } else {
                self.resultsView
            }
        }
        .background(ColorPalette.background)
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: self.$query, prompt: Text("Search documents and tools"))
        .onChange(of: self.query) { _, newValue in
            // Reuse the archive's matching rules (filename + indexed page text).
            self.viewModel.searchText = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .onAppear() {
            self.viewModel.refresh()
        }
        .animation(DS.Motion.smooth, value: self.trimmedQuery)
    }

    // MARK: - Results

    private var resultsView: some View {
        LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if !self.matchingDocuments.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    SectionHeaderView(title: String(localized: "Documents"))
                    ForEach(self.matchingDocuments) { pdf in
                        DocumentRowView(pdf: pdf,
                                        isSelected: self.selection?.wrappedValue == pdf.documentId) {
                            self.open(pdf)
                        }
                    }
                }
            }
            if !self.matchingTools.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    SectionHeaderView(title: String(localized: "Tools"))
                    ForEach(self.matchingTools) { tool in
                        ToolRowView(title: tool.title,
                                    subtitle: tool.subtitle,
                                    systemImage: tool.systemImage,
                                    tint: tool.tint,
                                    isPremium: tool.isPremium) {
                            self.run(tool)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
    }

    // MARK: - Empty query

    private var suggestionsView: some View {
        LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                SectionHeaderView(title: String(localized: "Quick actions"))
                ForEach(ToolUsageTracker.quickActions(from: ToolCatalog.allTools)) { tool in
                    ToolRowView(title: tool.title,
                                subtitle: tool.subtitle,
                                systemImage: tool.systemImage,
                                tint: tool.tint,
                                isPremium: tool.isPremium) {
                        self.run(tool)
                    }
                }
            }
            if case .data(let items) = self.viewModel.asyncItems.status, !items.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    SectionHeaderView(title: String(localized: "Recent documents"))
                    ForEach(Array(items.sorted { $0.creationDate > $1.creationDate }.prefix(5))) { pdf in
                        DocumentRowView(pdf: pdf,
                                        isSelected: self.selection?.wrappedValue == pdf.documentId) {
                            self.open(pdf)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
    }

    private func run(_ tool: PdfTool) {
        ToolUsageTracker.registerUse(of: tool.action)
        self.mainCoordinator.runTool(tool.action)
    }

    /// Same rule as the Files grid: preview where there is a pane for it, open
    /// the editor where there is not.
    private func open(_ pdf: Pdf) {
        if let selection = self.selection {
            selection.wrappedValue = pdf.documentId
        } else {
            self.viewModel.editItem(item: pdf)
        }
    }
}

#Preview {
    NavigationStack {
        GlobalSearchView()
            .navigationTitle("Search")
    }
}
