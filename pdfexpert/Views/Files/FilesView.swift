//
//  FilesView.swift
//  PdfExpert
//
//  The documents the user has saved — now the app's home. Replaces the old
//  Archive list: same data, but browsable as a grid, sortable, and with the
//  document actions one long-press away.
//

import SwiftUI
import Factory

enum FilesLayout: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .grid: return String(localized: "Grid")
        case .list: return String(localized: "List")
        }
    }

    var systemImage: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

enum FilesSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case name
    case pages

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .newest: return String(localized: "Newest first")
        case .oldest: return String(localized: "Oldest first")
        case .name: return String(localized: "Name")
        case .pages: return String(localized: "Page count")
        }
    }

    func sort(_ items: [Pdf]) -> [Pdf] {
        switch self {
        case .newest: return items.sorted { $0.creationDate > $1.creationDate }
        case .oldest: return items.sorted { $0.creationDate < $1.creationDate }
        case .name: return items.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .pages: return items.sorted { $0.pageCount > $1.pageCount }
        }
    }
}

struct FilesView: View {

    @InjectedObject(\.archiveViewModel) var viewModel
    @Injected(\.mainCoordinator) private var mainCoordinator

    @AppStorage("filesLayout") private var layout: FilesLayout = .grid
    @AppStorage("filesSort") private var sort: FilesSort = .newest

    @State private var pdfToDelete: Pdf? = nil
    @State private var pdfForInfo: Pdf? = nil
    @State private var importTutorialShow: Bool = false

    /// Three columns on a phone, more on an iPad: page previews are recognisable
    /// well below thumbnail-per-half-screen size, and the denser grid shows a
    /// realistic archive without scrolling.
    private static let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 104, maximum: 190), spacing: DS.Spacing.xs)
    ]

    var body: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()
            self.content
            if self.viewModel.isLoading {
                AnimationType.dots.view.background(.black.opacity(0.25))
            }
        }
        .searchable(text: self.$viewModel.searchText, prompt: Text("Search PDFs"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                self.viewOptionsMenu
            }
        }
        .safeAreaInset(edge: .bottom) {
            self.newDocumentButton
        }
        .onAppear() {
            self.viewModel.onAppear()
        }
        .asyncView(asyncOperation: self.$viewModel.asyncItemDelete)
        .fullScreenCover(isPresented: self.$importTutorialShow) {
            ImportTutorialView()
        }
        .sheet(item: self.$pdfForInfo) { pdf in
            let inputParameter = PdfMetadataViewModel
                .InputParameter(pdf: pdf,
                                onConfirm: { self.viewModel.updateItem(item: $0) })
            PdfMetadataView(viewModel: Container.shared.pdfMetadataViewModel(inputParameter))
        }
        // Bound to the item itself so dismissing by tapping outside also clears
        // it — a `.constant` binding would leave the dialog stuck open.
        .confirmationDialog(Text("Are you sure?"),
                            isPresented: Binding(get: { self.pdfToDelete != nil },
                                                 set: { if !$0 { self.pdfToDelete = nil } }),
                            titleVisibility: .visible,
                            presenting: self.pdfToDelete) { pdf in
            Button("Delete", role: .destructive) {
                self.pdfToDelete = nil
                withAnimation(DS.Motion.smooth) {
                    self.viewModel.delete(item: pdf)
                }
            }
            Button("Cancel", role: .cancel) { self.pdfToDelete = nil }
        }
        .showShareView(coordinator: self.viewModel.pdfShareCoordinator)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch self.viewModel.asyncItems.status {
        case .empty:
            Color.clear
        case .loading:
            AnimationType.dots.view
        case .data(let items):
            self.documentsView(items: self.sort.sort(self.viewModel.filteredItems(items)))
        case .error:
            self.errorView
        }
    }

    @ViewBuilder private func documentsView(items: [Pdf]) -> some View {
        if items.isEmpty {
            if !self.viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: self.viewModel.searchText)
            } else {
                self.emptyView
            }
        } else {
            ScrollView {
                Group {
                    switch self.layout {
                    case .grid:
                        LazyVGrid(columns: Self.gridColumns, spacing: DS.Spacing.xs) {
                            ForEach(items) { item in
                                DocumentCardView(pdf: item) { self.viewModel.editItem(item: item) }
                                    .contextMenu { self.documentActions(for: item) }
                            }
                        }
                    case .list:
                        LazyVStack(spacing: DS.Spacing.xs) {
                            ForEach(items) { item in
                                DocumentRowView(pdf: item) { self.viewModel.editItem(item: item) }
                                    .contextMenu { self.documentActions(for: item) }
                            }
                        }
                    }
                }
                .padding(DS.Spacing.md)
                .animation(DS.Motion.smooth, value: self.layout)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    @ViewBuilder private func documentActions(for pdf: Pdf) -> some View {
        Button {
            self.viewModel.editItem(item: pdf)
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button {
            self.viewModel.shareItem(item: pdf)
        } label: {
            Label("Share pdf", systemImage: "square.and.arrow.up")
        }
        Button {
            self.pdfForInfo = pdf
        } label: {
            Label("Document info", systemImage: "info.circle")
        }
        Divider()
        Button(role: .destructive) {
            self.pdfToDelete = pdf
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Chrome

    private var viewOptionsMenu: some View {
        Menu {
            Picker(selection: self.$layout) {
                ForEach(FilesLayout.allCases) { layout in
                    Label(layout.title, systemImage: layout.systemImage).tag(layout)
                }
            } label: {
                Text("View")
            }
            .pickerStyle(.inline)

            Picker(selection: self.$sort) {
                ForEach(FilesSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            } label: {
                Text("Sort by")
            }
            .pickerStyle(.inline)
        } label: {
            Label("View options", systemImage: "ellipsis")
        }
    }

    /// Floating entry point for new documents. Glass, because it sits above the
    /// scrolling content rather than being part of it.
    private var newDocumentButton: some View {
        HStack {
            Spacer()
            Menu {
                Button {
                    self.mainCoordinator.runTool(.scan)
                } label: {
                    Label("Scan", systemImage: "doc.viewfinder")
                }
                Button {
                    self.mainCoordinator.runTool(.imageToPdf)
                } label: {
                    Label("Image to PDF", systemImage: "photo.on.rectangle.angled")
                }
                Button {
                    self.mainCoordinator.runTool(.importPdf)
                } label: {
                    Label("Import PDF", systemImage: "tray.and.arrow.down")
                }
                Button {
                    self.mainCoordinator.runTool(.createPdf)
                } label: {
                    Label("Create PDF", systemImage: "doc.badge.plus")
                }
                Divider()
                Button {
                    self.importTutorialShow = true
                } label: {
                    Label("Convert from any file", systemImage: "questionmark.circle")
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("New")
                        .font(forCategory: .button)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.lg)
                .frame(height: 50)
                .contentShape(.capsule)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(ColorPalette.accent)
            .accessibilityLabel(Text("New document"))
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xs)
    }

    // MARK: - States

    private var emptyView: some View {
        ContentUnavailableView {
            Label("You haven’t converted any files yet", systemImage: "tray")
        } description: {
            Text("Scan a document, turn photos into a PDF, or import a file to get started.")
        } actions: {
            PrimaryActionButton(title: String(localized: "Scan"), systemImage: "doc.viewfinder") {
                self.mainCoordinator.runTool(.scan)
            }
            .frame(maxWidth: 260)
            Button("Convert from any file") {
                self.importTutorialShow = true
            }
            .font(forCategory: .linkText)
        }
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Oh nou", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Something went wrong,\nmind trying again?")
        } actions: {
            PrimaryActionButton(title: String(localized: "Retry")) {
                self.viewModel.refresh()
            }
            .frame(maxWidth: 220)
        }
    }
}

extension Pdf {

    var pageCountText: String {
        String(localized: "\(self.pageCount) pages")
    }
}

#Preview {
    NavigationStack {
        FilesView()
            .navigationTitle("Files")
    }
}
