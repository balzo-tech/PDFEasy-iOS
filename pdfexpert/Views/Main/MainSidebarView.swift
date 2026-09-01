//
//  MainSidebarView.swift
//  PdfExpert
//
//  The first column of the iPad layout. It carries the same four sections the
//  phone's tab bar does, and below them the archive's own structure: folders
//  navigate — picking one shows the Files grid narrowed to it — while tags stay
//  additive toggles layered on top of whatever folder is showing.
//

import SwiftUI
import Factory

/// What the sidebar highlights. Folders are part of the selection because
/// choosing one *is* navigation; tags are not, because several can be on at once.
enum SidebarSelection: Hashable {
    case section(MainTab)
    case folder(id: String)
    case unfiled
}

struct MainSidebarView: View {

    @ObservedObject var archive: ArchiveViewModel

    @Binding var tab: MainTab
    let onManageFiling: () -> Void
    let onShowSettings: () -> Void
    let onUpgrade: () -> Void

    /// Derived rather than stored: the sidebar shows what the Files grid is
    /// actually filtered to, so a filter cleared from anywhere else is reflected
    /// here without a second source of truth to keep in step.
    private var selection: Binding<SidebarSelection?> {
        Binding(
            get: {
                guard self.tab == .files else { return .section(self.tab) }
                switch self.archive.folderFilter {
                case .all: return .section(.files)
                case .unfiled: return .unfiled
                case .folder(let id): return .folder(id: id)
                }
            },
            set: { newValue in
                guard let newValue else { return }
                switch newValue {
                case .section(let tab):
                    // "Files" means the whole archive, so it also drops the folder.
                    if tab == .files { self.archive.folderFilter = .all }
                    self.tab = tab
                case .folder(let id):
                    self.archive.folderFilter = .folder(id: id)
                    self.tab = .files
                case .unfiled:
                    self.archive.folderFilter = .unfiled
                    self.tab = .files
                }
            }
        )
    }

    var body: some View {
        List(selection: self.selection) {
            Section {
                ForEach(MainTab.sidebarCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(SidebarSelection.section(tab))
                }
            }

            if !self.archive.folders.isEmpty {
                Section(String(localized: "Folders")) {
                    ForEach(self.archive.folders) { folder in
                        Label {
                            Text(folder.name)
                        } icon: {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(folder.color.color)
                        }
                        .tag(SidebarSelection.folder(id: folder.id))
                    }
                    Label("Unfiled", systemImage: "tray")
                        .tag(SidebarSelection.unfiled)
                }
            }

            if !self.archive.tags.isEmpty {
                Section(String(localized: "Tags")) {
                    ForEach(self.archive.tags) { tag in
                        self.tagRow(for: tag)
                    }
                }
            }

            Section {
                Button(action: self.onManageFiling) {
                    Label("Folders & Tags", systemImage: "folder.badge.gearshape")
                }
                .foregroundStyle(ColorPalette.textSecondary)
            }
        }
        .listStyle(.sidebar)
        // The app's own name, from one place: this said "PDF Easy" — the name it
        // had two names ago — to every iPad in every language.
        .navigationTitle(K.Misc.AppTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: self.onShowSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                ProUpgradeButton(onTap: self.onUpgrade)
            }
        }
    }

    /// A tag narrows down whatever is already showing, so it reads as a switch
    /// rather than as a destination: tapping toggles it and leaves the rest alone.
    private func tagRow(for tag: Tag) -> some View {
        Button {
            withAnimation(DS.Motion.quick) {
                self.archive.toggleTagFilter(tag)
                self.tab = .files
            }
        } label: {
            HStack {
                Label {
                    Text(tag.name)
                        .foregroundStyle(ColorPalette.textPrimary)
                } icon: {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(tag.color.color)
                }
                Spacer(minLength: DS.Spacing.xs)
                if self.archive.selectedTagIds.contains(tag.id) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ColorPalette.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(self.archive.selectedTagIds.contains(tag.id) ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    NavigationSplitView {
        MainSidebarView(archive: Container.shared.archiveViewModel(),
                        tab: .constant(.files),
                        onManageFiling: {},
                        onShowSettings: {},
                    onUpgrade: {})
    } detail: {
        Color.clear
    }
}
