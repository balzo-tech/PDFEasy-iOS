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

/// A folder or tag being created from a document's context menu.
enum QuickLabelRequest: Identifiable {

    case folder(pdf: Pdf)
    case tag(pdf: Pdf)

    var id: String {
        switch self {
        case .folder(let pdf): return "folder-\(pdf.filename)"
        case .tag(let pdf): return "tag-\(pdf.filename)"
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
    @State private var organizerShow: Bool = false
    /// A folder or tag being created from a document's own menu: once saved it is
    /// applied to that document straight away.
    @State private var quickLabel: QuickLabelRequest? = nil

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
        .safeAreaInset(edge: .top, spacing: 0) {
            // Only worth the vertical space once there is something to filter by.
            if !self.viewModel.folders.isEmpty || !self.viewModel.tags.isEmpty {
                FilesFilterBar(folders: self.viewModel.folders,
                               tags: self.viewModel.tags,
                               folderFilter: self.$viewModel.folderFilter,
                               selectedTagIds: self.$viewModel.selectedTagIds,
                               onManage: { self.organizerShow = true })
                    .background(.bar)
            }
        }
        .safeAreaInset(edge: .bottom) {
            self.newDocumentButton
        }
        .onAppear() {
            self.viewModel.onAppear()
            #if DEBUG
            // debugShowOrganizer=YES opens the folders/tags sheet straight away,
            // the simulator takes no programmatic taps.
            if UserDefaults.standard.bool(forKey: "debugShowOrganizer") {
                self.organizerShow = true
            }
            #endif
        }
        .asyncView(asyncOperation: self.$viewModel.asyncItemDelete)
        .asyncView(asyncOperation: self.$viewModel.asyncFiling)
        .fullScreenCover(isPresented: self.$importTutorialShow) {
            ImportTutorialView()
        }
        .sheet(isPresented: self.$organizerShow) {
            ArchiveOrganizerView(viewModel: self.viewModel)
        }
        .sheet(item: self.$quickLabel) { request in
            self.quickLabelEditor(for: request)
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
            } else if self.viewModel.filter.isFiltering {
                self.noMatchesView
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
        self.folderMenu(for: pdf)
        self.tagsMenu(for: pdf)
        Divider()
        Button(role: .destructive) {
            self.pdfToDelete = pdf
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    /// Filing lives in the document's own menu: it is a property of that
    /// document, not a mode the whole screen has to enter.
    @ViewBuilder private func folderMenu(for pdf: Pdf) -> some View {
        Menu {
            ForEach(self.viewModel.folders) { folder in
                Button {
                    self.viewModel.setFolder(folder, for: pdf)
                } label: {
                    Label(folder.name, systemImage: pdf.folderId == folder.id ? "checkmark" : "folder")
                }
            }
            if pdf.folder != nil {
                Divider()
                Button {
                    self.viewModel.setFolder(nil, for: pdf)
                } label: {
                    Label("Remove from folder", systemImage: "tray")
                }
            }
            Divider()
            Button {
                self.quickLabel = .folder(pdf: pdf)
            } label: {
                Label("New folder…", systemImage: "folder.badge.plus")
            }
        } label: {
            Label("Move to", systemImage: "folder")
        }
    }

    @ViewBuilder private func tagsMenu(for pdf: Pdf) -> some View {
        Menu {
            ForEach(self.viewModel.tags) { tag in
                Button {
                    self.viewModel.toggleTag(tag, for: pdf)
                } label: {
                    Label(tag.name, systemImage: pdf.tagIds.contains(tag.id) ? "checkmark" : "circle")
                }
            }
            if !self.viewModel.tags.isEmpty {
                Divider()
            }
            Button {
                self.quickLabel = .tag(pdf: pdf)
            } label: {
                Label("New tag…", systemImage: "plus")
            }
        } label: {
            Label("Tags", systemImage: "tag")
        }
    }

    /// Creating a folder or tag from a document's menu also files that document
    /// into it — otherwise the user has to go and repeat the assignment.
    @ViewBuilder private func quickLabelEditor(for request: QuickLabelRequest) -> some View {
        switch request {
        case .folder(let pdf):
            LabelEditorView(title: String(localized: "New folder"),
                            placeholder: String(localized: "Folder name"),
                            color: self.viewModel.suggestedFolderColor) { name, color in
                if let folder = self.viewModel.createFolder(name: name, color: color) {
                    self.viewModel.setFolder(folder, for: pdf)
                }
            }
        case .tag(let pdf):
            LabelEditorView(title: String(localized: "New tag"),
                            placeholder: String(localized: "Tag name"),
                            color: self.viewModel.suggestedTagColor) { name, color in
                if let tag = self.viewModel.createTag(name: name, color: color) {
                    self.viewModel.toggleTag(tag, for: pdf)
                }
            }
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

            Divider()

            Button {
                self.organizerShow = true
            } label: {
                Label("Folders & Tags", systemImage: "folder.badge.gearshape")
            }
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

    private var noMatchesView: some View {
        ContentUnavailableView {
            Label("Nothing filed here yet", systemImage: "folder")
        } description: {
            Text("No document matches the folder and tags you picked.")
        } actions: {
            Button("Clear filters") {
                withAnimation(DS.Motion.quick) { self.viewModel.clearFilters() }
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
