//
//  FilesView.swift
//  PdfExpert
//
//  The documents the user has saved — the app's home. Replaces the old Archive
//  list: same data, but browsable as a grid, sortable, and with the document
//  actions one long-press away.
//
//  It is the whole screen in the tab shell and the middle column in the iPad
//  split. The difference is `selection`: when it is bound, picking a document
//  previews it in the detail column instead of opening the editor, and the
//  folder and tag chips move to the sidebar.
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

    @ObservedObject var viewModel: ArchiveViewModel
    /// Bound only by the split shell. See the note at the top of the file.
    var selection: Binding<String?>? = nil

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

    /// In the split layout the folders and tags live in the sidebar, so the chip
    /// bar would be a second copy of the same controls.
    private var showsFilterBar: Bool { self.selection == nil }

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
            if self.showsFilterBar, !self.viewModel.folders.isEmpty || !self.viewModel.tags.isEmpty {
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
        // Dropping a file here imports it, the same as picking it from the
        // "New" menu — on an iPad running two apps side by side that is the
        // first thing people try.
        .documentDropDestination(inset: DS.Spacing.xs) { pdf in
            self.mainCoordinator.showPdfEditFlow(pdf: pdf, isNewPdf: true)
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
            QuickLabelEditorView(viewModel: self.viewModel, request: request)
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
                                DocumentCardView(pdf: item,
                                                 isSelected: self.isSelected(item),
                                                 onOpen: { self.open(item) })
                                    .contextMenu { self.documentActions(for: item) }
                            }
                        }
                    case .list:
                        LazyVStack(spacing: DS.Spacing.xs) {
                            ForEach(items) { item in
                                DocumentRowView(pdf: item,
                                                isSelected: self.isSelected(item),
                                                onOpen: { self.open(item) })
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
        DocumentActionsMenu(viewModel: self.viewModel,
                            pdf: pdf,
                            onInfo: { self.pdfForInfo = $0 },
                            onDelete: { self.pdfToDelete = $0 },
                            onQuickLabel: { self.quickLabel = $0 })
    }

    // MARK: - Selection

    private func isSelected(_ pdf: Pdf) -> Bool {
        self.selection?.wrappedValue == pdf.documentId
    }

    /// One tap means "show me this" where there is a pane to show it in, and
    /// "open this" where there is not.
    private func open(_ pdf: Pdf) {
        if let selection = self.selection {
            selection.wrappedValue = pdf.documentId
        } else {
            self.viewModel.editItem(item: pdf)
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
        FilesView(viewModel: Container.shared.archiveViewModel())
            .navigationTitle("Files")
    }
}
