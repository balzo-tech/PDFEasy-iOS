//
//  ArchiveOrganizerView.swift
//  PdfExpert
//
//  Where folders and tags are created, renamed, recoloured and deleted. Reached
//  from the filter bar and from the Files view options menu.
//

import SwiftUI

/// Name + colour, used both to create and to rename.
struct LabelEditorView: View {

    let title: String
    let placeholder: String
    @State private var name: String
    @State private var color: ArchiveColor
    let onSave: (String, ArchiveColor) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    init(title: String,
         placeholder: String,
         name: String = "",
         color: ArchiveColor = .blue,
         onSave: @escaping (String, ArchiveColor) -> Void) {
        self.title = title
        self.placeholder = placeholder
        self._name = State(initialValue: name)
        self._color = State(initialValue: color)
        self.onSave = onSave
    }

    private var trimmedName: String {
        self.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(self.placeholder, text: self.$name)
                        .focused(self.$nameFocused)
                        .submitLabel(.done)
                        .onSubmit { self.save() }
                }
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: DS.Spacing.sm)],
                              spacing: DS.Spacing.sm) {
                        ForEach(ArchiveColor.allCases) { color in
                            Button {
                                self.color = color
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if color == self.color {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: DS.Size.tapTarget)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(color.accessibilityName))
                            .accessibilityAddTraits(color == self.color ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                }
            }
            .navigationTitle(self.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { self.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { self.save() }
                        .disabled(self.trimmedName.isEmpty)
                }
            }
            .onAppear { self.nameFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard !self.trimmedName.isEmpty else { return }
        self.onSave(self.trimmedName, self.color)
        self.dismiss()
    }
}

struct ArchiveOrganizerView: View {

    @ObservedObject var viewModel: ArchiveViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var editor: LabelEditorRequest? = nil
    @State private var folderToDelete: Folder? = nil
    @State private var tagToDelete: Tag? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(self.viewModel.folders) { folder in
                        Button {
                            self.editor = .renameFolder(folder)
                        } label: {
                            LabelRow(name: folder.name,
                                     systemImage: "folder.fill",
                                     color: folder.color,
                                     detail: self.documentCountText(for: folder))
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", role: .destructive) { self.folderToDelete = folder }
                        }
                    }
                    Button {
                        self.editor = .newFolder
                    } label: {
                        Label("New folder", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Folders")
                } footer: {
                    Text("Deleting a folder keeps its documents — they go back to Unfiled.")
                }

                Section {
                    ForEach(self.viewModel.tags) { tag in
                        Button {
                            self.editor = .renameTag(tag)
                        } label: {
                            LabelRow(name: tag.name,
                                     systemImage: "circle.fill",
                                     color: tag.color,
                                     detail: self.documentCountText(for: tag))
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", role: .destructive) { self.tagToDelete = tag }
                        }
                    }
                    Button {
                        self.editor = .newTag
                    } label: {
                        Label("New tag", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Tags")
                }
            }
            .navigationTitle("Folders & Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { self.dismiss() }
                }
            }
            .sheet(item: self.$editor) { request in
                self.editorView(for: request)
            }
            .confirmationDialog(Text("Delete this folder?"),
                                isPresented: Binding(get: { self.folderToDelete != nil },
                                                     set: { if !$0 { self.folderToDelete = nil } }),
                                titleVisibility: .visible,
                                presenting: self.folderToDelete) { folder in
                Button("Delete", role: .destructive) {
                    self.folderToDelete = nil
                    self.viewModel.deleteFolder(folder)
                }
                Button("Cancel", role: .cancel) { self.folderToDelete = nil }
            } message: { _ in
                Text("The documents inside will be kept.")
            }
            .confirmationDialog(Text("Delete this tag?"),
                                isPresented: Binding(get: { self.tagToDelete != nil },
                                                     set: { if !$0 { self.tagToDelete = nil } }),
                                titleVisibility: .visible,
                                presenting: self.tagToDelete) { tag in
                Button("Delete", role: .destructive) {
                    self.tagToDelete = nil
                    self.viewModel.deleteTag(tag)
                }
                Button("Cancel", role: .cancel) { self.tagToDelete = nil }
            } message: { _ in
                Text("It will be removed from every document.")
            }
        }
    }

    @ViewBuilder private func editorView(for request: LabelEditorRequest) -> some View {
        switch request {
        case .newFolder:
            LabelEditorView(title: String(localized: "New folder"),
                            placeholder: String(localized: "Folder name"),
                            color: self.viewModel.suggestedFolderColor) { name, color in
                self.viewModel.createFolder(name: name, color: color)
            }
        case .renameFolder(let folder):
            LabelEditorView(title: String(localized: "Edit folder"),
                            placeholder: String(localized: "Folder name"),
                            name: folder.name,
                            color: folder.color) { name, color in
                var updated = folder
                updated.name = name
                updated.color = color
                self.viewModel.updateFolder(updated)
            }
        case .newTag:
            LabelEditorView(title: String(localized: "New tag"),
                            placeholder: String(localized: "Tag name"),
                            color: self.viewModel.suggestedTagColor) { name, color in
                self.viewModel.createTag(name: name, color: color)
            }
        case .renameTag(let tag):
            LabelEditorView(title: String(localized: "Edit tag"),
                            placeholder: String(localized: "Tag name"),
                            name: tag.name,
                            color: tag.color) { name, color in
                var updated = tag
                updated.name = name
                updated.color = color
                self.viewModel.updateTag(updated)
            }
        }
    }

    private func documentCountText(for folder: Folder) -> String {
        let count = self.viewModel.documents.filter { $0.folderId == folder.id }.count
        return String(localized: "\(count) documents")
    }

    private func documentCountText(for tag: Tag) -> String {
        let count = self.viewModel.documents.filter { $0.tagIds.contains(tag.id) }.count
        return String(localized: "\(count) documents")
    }
}

/// A row in the organizer: colour dot, name, and how much is filed under it.
private struct LabelRow: View {

    let name: String
    let systemImage: String
    let color: ArchiveColor
    let detail: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: self.systemImage)
                .font(.system(size: 15))
                .foregroundStyle(self.color.color)
                .frame(width: 24)
            Text(self.name)
                .foregroundStyle(ColorPalette.textPrimary)
            Spacer(minLength: DS.Spacing.xs)
            Text(self.detail)
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textSecondary)
        }
    }
}

enum LabelEditorRequest: Identifiable {

    case newFolder
    case renameFolder(Folder)
    case newTag
    case renameTag(Tag)

    var id: String {
        switch self {
        case .newFolder: return "new-folder"
        case .renameFolder(let folder): return "folder-\(folder.id)"
        case .newTag: return "new-tag"
        case .renameTag(let tag): return "tag-\(tag.id)"
        }
    }
}
