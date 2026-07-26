//
//  DocumentActions.swift
//  PdfExpert
//
//  Everything that can be done to a saved document, in one place. The Files grid
//  hangs it off a context menu and the iPad detail pane off a toolbar menu; both
//  read from here so the two never drift apart.
//

import SwiftUI

/// A folder or tag being created from a document's own menu.
enum QuickLabelRequest: Identifiable {

    case folder(pdf: Pdf)
    case tag(pdf: Pdf)

    var id: String {
        switch self {
        case .folder(let pdf): return "folder-\(pdf.documentId)"
        case .tag(let pdf): return "tag-\(pdf.documentId)"
        }
    }
}

struct DocumentActionsMenu: View {

    @ObservedObject var viewModel: ArchiveViewModel

    let pdf: Pdf
    /// Omitted by the detail pane, which already has Edit as its own button.
    var includesOpen: Bool = true
    let onInfo: (Pdf) -> Void
    let onDelete: (Pdf) -> Void
    let onQuickLabel: (QuickLabelRequest) -> Void

    var body: some View {
        if self.includesOpen {
            Button {
                self.viewModel.editItem(item: self.pdf)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        Button {
            self.viewModel.shareItem(item: self.pdf)
        } label: {
            Label("Share pdf", systemImage: "square.and.arrow.up")
        }
        Button {
            self.onInfo(self.pdf)
        } label: {
            Label("Document info", systemImage: "info.circle")
        }
        Divider()
        self.folderMenu
        self.tagsMenu
        Divider()
        Button(role: .destructive) {
            self.onDelete(self.pdf)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    /// Filing lives in the document's own menu: it is a property of that
    /// document, not a mode the whole screen has to enter.
    @ViewBuilder private var folderMenu: some View {
        Menu {
            ForEach(self.viewModel.folders) { folder in
                Button {
                    self.viewModel.setFolder(folder, for: self.pdf)
                } label: {
                    Label(folder.name,
                          systemImage: self.pdf.folderId == folder.id ? "checkmark" : "folder")
                }
            }
            if self.pdf.folder != nil {
                Divider()
                Button {
                    self.viewModel.setFolder(nil, for: self.pdf)
                } label: {
                    Label("Remove from folder", systemImage: "tray")
                }
            }
            Divider()
            Button {
                self.onQuickLabel(.folder(pdf: self.pdf))
            } label: {
                Label("New folder…", systemImage: "folder.badge.plus")
            }
        } label: {
            Label("Move to", systemImage: "folder")
        }
    }

    @ViewBuilder private var tagsMenu: some View {
        Menu {
            ForEach(self.viewModel.tags) { tag in
                Button {
                    self.viewModel.toggleTag(tag, for: self.pdf)
                } label: {
                    Label(tag.name,
                          systemImage: self.pdf.tagIds.contains(tag.id) ? "checkmark" : "circle")
                }
            }
            if !self.viewModel.tags.isEmpty {
                Divider()
            }
            Button {
                self.onQuickLabel(.tag(pdf: self.pdf))
            } label: {
                Label("New tag…", systemImage: "plus")
            }
        } label: {
            Label("Tags", systemImage: "tag")
        }
    }
}

/// Creating a folder or tag from a document's menu also files that document into
/// it — otherwise the user has to go and repeat the assignment.
struct QuickLabelEditorView: View {

    @ObservedObject var viewModel: ArchiveViewModel

    let request: QuickLabelRequest

    var body: some View {
        switch self.request {
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
}
