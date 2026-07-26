//
//  MainSplitView.swift
//  PdfExpert
//
//  The iPad shell. Three columns: the sections and the archive's own structure
//  on the left, the list of whatever that section holds in the middle, and the
//  selected thing on the right — a document to read, a tool to start, or a
//  conversation to carry on. The tab bar the phone uses would waste the width
//  and hide the folders behind a chip bar.
//

import SwiftUI
import Factory

struct MainSplitView: View {

    @ObservedObject var archive: ArchiveViewModel
    @ObservedObject var tools: HomeViewModel
    @ObservedObject var chat: ChatPdfSelectionViewModel

    @InjectedObject(\.mainCoordinator) private var mainCoordinator

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var organizerShow: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: self.$columnVisibility) {
            MainSidebarView(archive: self.archive,
                            tab: self.$mainCoordinator.tab,
                            onManageFiling: { self.organizerShow = true },
                            onShowSettings: { self.mainCoordinator.settingsShow = true })
                // Kept narrow so all three columns still fit an iPad held in
                // portrait; the sidebar holds short labels and folder names.
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } content: {
            self.contentColumn
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            self.detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .tint(ColorPalette.accent)
        .sheet(isPresented: self.$organizerShow) {
            ArchiveOrganizerView(viewModel: self.archive)
        }
    }

    // MARK: - Columns

    private var contentColumn: some View {
        NavigationStack {
            Group {
                switch self.mainCoordinator.tab {
                case .files:
                    FilesView(viewModel: self.archive,
                              selection: self.$mainCoordinator.selectedDocumentId)
                case .tools:
                    ToolsView(viewModel: self.tools,
                              selection: self.$mainCoordinator.selectedTool)
                case .chat:
                    ChatPdfSelectionView(viewModel: self.chat, presentsChatInline: true)
                case .search:
                    GlobalSearchView(selection: self.$mainCoordinator.selectedDocumentId)
                case .scanner:
                    ScannerHomeView(viewModel: self.archive,
                                    selection: self.$mainCoordinator.selectedDocumentId)
                }
            }
            .navigationTitle(self.mainCoordinator.tab.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private var detailColumn: some View {
        switch self.mainCoordinator.tab {
        case .files, .search, .scanner:
            NavigationStack {
                DocumentDetailView(viewModel: self.archive,
                                   documentId: self.mainCoordinator.selectedDocumentId)
            }
        case .tools:
            NavigationStack {
                ToolDetailView(tool: self.mainCoordinator.selectedTool) { tool in
                    ToolUsageTracker.registerUse(of: tool.action)
                    self.tools.performHomeAction(tool.action)
                }
            }
        case .chat:
            self.chatDetail
        }
    }

    /// The conversation belongs beside the document that started it, not on top
    /// of it: on a phone ChatPDF takes the whole screen, here it is the third
    /// column and the picker stays visible next to it.
    @ViewBuilder private var chatDetail: some View {
        if let initParams = self.chat.chatPdfInitParams {
            let parameters = ChatPdfViewModel.Parameters(chatPdfInitParams: initParams)
            ChatPdfView(viewModel: Container.shared.chatPdfViewModel(parameters),
                        onClose: { self.chat.chatPdfInitParams = nil })
                .id(initParams)
        } else {
            NavigationStack {
                ContentUnavailableView {
                    Label("No conversation yet", systemImage: "ellipses.bubble")
                } description: {
                    Text("Choose a PDF and the conversation appears here.")
                }
                .background(ColorPalette.background)
            }
        }
    }
}

#Preview {
    MainSplitView(archive: Container.shared.archiveViewModel(),
                  tools: Container.shared.homeViewModel(),
                  chat: Container.shared.chatPdfSelectionViewModel())
}
