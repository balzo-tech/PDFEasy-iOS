//
//  MainTabView.swift
//  PdfExpert
//
//  The compact shell: documents first, then the tool catalog, ChatPDF, and a
//  search tab that spans both. The tab bar is the system's Liquid Glass bar and
//  pulls back as the user scrolls into content. `RootShellView` swaps it for
//  `MainSplitView` as soon as the window is wide enough for columns.
//

import SwiftUI
import Factory

struct MainTabView: View {

    @ObservedObject var archive: ArchiveViewModel
    @ObservedObject var tools: HomeViewModel
    @ObservedObject var chat: ChatPdfSelectionViewModel

    @InjectedObject(\.mainCoordinator) private var mainCoordinator

    var body: some View {
        TabView(selection: self.$mainCoordinator.tab) {
            Tab(MainTab.files.title,
                systemImage: MainTab.files.systemImage,
                value: MainTab.files) {
                self.rootView(for: .files)
            }

            Tab(MainTab.tools.title,
                systemImage: MainTab.tools.systemImage,
                value: MainTab.tools) {
                self.rootView(for: .tools)
            }

            Tab(MainTab.scanner.title,
                systemImage: MainTab.scanner.systemImage,
                value: MainTab.scanner) {
                self.rootView(for: .scanner)
            }

            Tab(MainTab.chat.title,
                systemImage: MainTab.chat.systemImage,
                value: MainTab.chat) {
                self.rootView(for: .chat)
            }

            Tab(MainTab.search.title,
                systemImage: MainTab.search.systemImage,
                value: MainTab.search,
                role: .search) {
                self.rootView(for: .search)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(ColorPalette.accent)
    }

    @MainActor @ViewBuilder private func rootView(for tab: MainTab) -> some View {
        NavigationStack {
            Group {
                switch tab {
                case .files: FilesView(viewModel: self.archive)
                case .tools: ToolsView(viewModel: self.tools)
                case .chat: ChatPdfSelectionView(viewModel: self.chat)
                case .scanner: ScannerHomeView(viewModel: self.archive)
                case .search: GlobalSearchView()
                }
            }
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(tab == .files ? .large : .inline)
            .settingsButton(showSettings: self.$mainCoordinator.settingsShow)
            .proUpgradeButton(showSubscription: self.$mainCoordinator.subscriptionShow)
        }
    }
}

fileprivate extension View {

    func settingsButton(showSettings: Binding<Bool>) -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings.wrappedValue = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }

    /// Opposite the settings gear, on every tab: subscribing should not require
    /// finding a locked feature first.
    func proUpgradeButton(showSubscription: Binding<Bool>) -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProUpgradeButton { showSubscription.wrappedValue = true }
            }
        }
    }
}

#Preview {
    MainTabView(archive: Container.shared.archiveViewModel(),
                tools: Container.shared.homeViewModel(),
                chat: Container.shared.chatPdfSelectionViewModel())
}
