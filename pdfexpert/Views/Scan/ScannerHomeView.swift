//
//  ScannerHomeView.swift
//  PdfExpert
//
//  The Scanner tab: everything the camera has produced, and a button to produce
//  more.
//
//  The documents themselves live in the same archive as the rest — a scan is a
//  PDF like any other, and giving the scanner its own store would mean two
//  places to search, two things to sync and two answers to "where did my file
//  go". What the tab does instead is narrow the archive to `PdfSource.scan`,
//  which is the one thing the Files tab cannot express.
//

import SwiftUI
import Factory

struct ScannerHomeView: View {

    @ObservedObject var viewModel: ArchiveViewModel
    /// Bound by the iPad split, exactly as in `FilesView`: picking a scan there
    /// previews it in the detail column instead of opening the editor.
    var selection: Binding<String?>? = nil

    @InjectedObject(\.mainCoordinator) private var mainCoordinator
    @Injected(\.analyticsManager) private var analyticsManager

    /// Its own search text rather than the archive's: the two tabs are two
    /// places, and typing in one should not filter the other.
    @State private var searchText: String = ""
    @State private var pdfToDelete: Pdf? = nil

    private static let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 104, maximum: 190), spacing: DS.Spacing.xs)
    ]

    var body: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()
            self.content
        }
        .searchable(text: self.$searchText, prompt: Text("Search scans"))
        .safeAreaInset(edge: .bottom) {
            self.scanButton
        }
        .onAppear {
            self.analyticsManager.track(event: .reportScreen(.scanLibrary))
            self.viewModel.refresh()
        }
        .confirmationDialog(Text("Are you sure?"),
                            isPresented: Binding(get: { self.pdfToDelete != nil },
                                                 set: { if !$0 { self.pdfToDelete = nil } }),
                            titleVisibility: .visible,
                            presenting: self.pdfToDelete) { pdf in
            Button("Delete", role: .destructive) {
                self.pdfToDelete = nil
                withAnimation(DS.Motion.smooth) { self.viewModel.delete(item: pdf) }
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
            self.scansView(items: self.scans(in: items))
        case .error:
            self.errorView
        }
    }

    /// The archive, narrowed to what the camera made and to what the user typed.
    private func scans(in items: [Pdf]) -> [Pdf] {
        let scans = items.filter { $0.source == .scan }
        let query = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scans }
        return scans.filter {
            ArchiveFilter.matches($0.filename, query) || ArchiveFilter.matches($0.searchableText, query)
        }
    }

    @ViewBuilder private func scansView(items: [Pdf]) -> some View {
        if items.isEmpty {
            if !self.searchText.isEmpty {
                ContentUnavailableView.search(text: self.searchText)
            } else {
                self.emptyView
            }
        } else {
            ScrollView {
                LazyVGrid(columns: Self.gridColumns, spacing: DS.Spacing.xs) {
                    ForEach(items) { item in
                        DocumentCardView(pdf: item,
                                         isSelected: self.selection?.wrappedValue == item.documentId,
                                         onOpen: { self.open(item) })
                            .contextMenu {
                                DocumentActionsMenu(viewModel: self.viewModel,
                                                    pdf: item,
                                                    onInfo: { _ in },
                                                    onDelete: { self.pdfToDelete = $0 },
                                                    onQuickLabel: { _ in })
                            }
                    }
                }
                .padding(DS.Spacing.md)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func open(_ pdf: Pdf) {
        if let selection = self.selection {
            selection.wrappedValue = pdf.documentId
        } else {
            self.viewModel.editItem(item: pdf)
        }
    }

    // MARK: - Chrome

    /// The shutter, essentially: round, accented, and the only thing on the
    /// screen when there is nothing scanned yet.
    private var scanButton: some View {
        HStack {
            Spacer()
            Button {
                self.mainCoordinator.startScan()
            } label: {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .contentShape(.circle)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(ColorPalette.accent)
            .accessibilityLabel(Text("Scan a document"))
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xs)
    }

    // MARK: - States

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No scans yet", systemImage: "doc.viewfinder")
        } description: {
            Text("Point the camera at a page and it becomes a PDF, straightened and cleaned up.")
        } actions: {
            PrimaryActionButton(title: String(localized: "Start scanning"), systemImage: "camera") {
                self.mainCoordinator.startScan()
            }
            .frame(maxWidth: 260)
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

#Preview {
    NavigationStack {
        ScannerHomeView(viewModel: Container.shared.archiveViewModel())
            .navigationTitle("Scanner")
    }
}
