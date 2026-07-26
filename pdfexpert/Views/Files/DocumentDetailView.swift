//
//  DocumentDetailView.swift
//  PdfExpert
//
//  The third column of the iPad layout: the document that is selected in the
//  grid, readable at a useful size without opening the editor. Everything
//  destructive still goes through the same archive view model the grid uses, so
//  a change made here shows up there immediately.
//

import SwiftUI
import Factory

struct DocumentDetailView: View {

    @ObservedObject var viewModel: ArchiveViewModel

    /// `Pdf.documentId` rather than a `Pdf`: the archive hands out fresh values
    /// on every refresh, and a stored struct would stop matching them.
    let documentId: String?

    @State private var pdfForInfo: Pdf? = nil
    @State private var pdfToDelete: Pdf? = nil
    @State private var quickLabel: QuickLabelRequest? = nil

    private var pdf: Pdf? {
        guard let documentId = self.documentId else { return nil }
        return self.viewModel.documents.first { $0.documentId == documentId }
    }

    var body: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()
            if let pdf = self.pdf {
                self.detail(for: pdf)
            } else {
                self.emptyView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: self.$pdfForInfo) { pdf in
            let inputParameter = PdfMetadataViewModel
                .InputParameter(pdf: pdf,
                                onConfirm: { self.viewModel.updateItem(item: $0) })
            PdfMetadataView(viewModel: Container.shared.pdfMetadataViewModel(inputParameter))
        }
        .sheet(item: self.$quickLabel) { request in
            QuickLabelEditorView(viewModel: self.viewModel, request: request)
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
    }

    // MARK: - Document

    @ViewBuilder private func detail(for pdf: Pdf) -> some View {
        VStack(spacing: 0) {
            self.preview(for: pdf)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            self.summary(for: pdf)
        }
        .navigationTitle(pdf.displayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    DocumentActionsMenu(viewModel: self.viewModel,
                                        pdf: pdf,
                                        includesOpen: false,
                                        onInfo: { self.pdfForInfo = $0 },
                                        onDelete: { self.pdfToDelete = $0 },
                                        onQuickLabel: { self.quickLabel = $0 })
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    self.viewModel.editItem(item: pdf)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.glassProminent)
                .tint(ColorPalette.accent)
                .keyboardShortcut("e", modifiers: [.command])
            }
        }
    }

    /// A locked document cannot be rendered without its password, and PDFKit
    /// would put up its own prompt in the middle of the pane. Better to say so
    /// and let the user unlock it from the editor.
    @ViewBuilder private func preview(for pdf: Pdf) -> some View {
        if pdf.pdfDocument.isLocked {
            ContentUnavailableView {
                Label("This document is locked", systemImage: "lock")
            } description: {
                Text("Open it to enter its password.")
            }
        } else {
            // No drag-out from here on purpose: the pane scrolls and zooms, and
            // a long-press-to-drag would fight PDFKit's own gestures. The grid
            // card is where a document is picked up.
            PdfKitView(pdfDocument: pdf.pdfDocument,
                       backgroundColor: UIColor(ColorPalette.background),
                       usePaginator: false)
        }
    }

    /// The metadata that would otherwise be squeezed under a grid card: room
    /// here for the folder and the tags by name rather than as coloured dots.
    private func summary(for pdf: Pdf) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(pdf.filename)
                .font(forCategory: .body3)
                .foregroundStyle(ColorPalette.textPrimary)
                .lineLimit(2)
                .truncationMode(.middle)

            HStack(spacing: DS.Spacing.xs) {
                Text(pdf.metadataText)
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
                if pdf.password != nil {
                    Label("Protected", systemImage: "lock.fill")
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    self.viewModel.shareItem(item: pdf)
                } label: {
                    Label("Share pdf", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorPalette.accent)
                .accessibilityLabel(Text("Share pdf"))
            }

            if pdf.folder != nil || !pdf.tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Spacing.xxs) {
                        if let folder = pdf.folder {
                            FilterChip(title: folder.name,
                                       systemImage: "folder.fill",
                                       tint: folder.color.color,
                                       isSelected: true) {
                                self.viewModel.folderFilter = .folder(id: folder.id)
                            }
                        }
                        ForEach(pdf.tags) { tag in
                            FilterChip(title: tag.name,
                                       systemImage: "circle.fill",
                                       tint: tag.color.color,
                                       isSelected: true) {
                                withAnimation(DS.Motion.quick) { self.viewModel.toggleTagFilter(tag) }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No document selected", systemImage: "doc.text")
        } description: {
            Text("Pick a document to preview it here.")
        }
    }
}

#Preview {
    NavigationStack {
        DocumentDetailView(viewModel: Container.shared.archiveViewModel(), documentId: nil)
    }
}
