//
//  MainTabView.swift
//  PdfExpert
//
//  The app shell: documents first, then the tool catalog, ChatPDF, and a search
//  tab that spans both. The tab bar is the system's Liquid Glass bar and pulls
//  back as the user scrolls into content.
//

import SwiftUI
import Factory

struct MainTabView: View {

    @InjectedObject(\.mainCoordinator) var mainCoordinator

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
        .pdfEditFlowView(pdfEditFlowData: self.$mainCoordinator.pdfEditFlowData)
        .settingsView(showSettings: self.$mainCoordinator.settingsShow)
    }

    @MainActor @ViewBuilder private func rootView(for tab: MainTab) -> some View {
        NavigationStack {
            Group {
                switch tab {
                case .files: FilesView()
                case .tools: ToolsView()
                case .chat: ChatPdfSelectionView()
                case .search: GlobalSearchView()
                }
            }
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(tab == .files ? .large : .inline)
            .settingsButton(showSettings: self.$mainCoordinator.settingsShow)
        }
    }
}

fileprivate extension View {

    func pdfEditFlowView(pdfEditFlowData: Binding<PdfEditFlowData?>) -> some View {
        self.fullScreenCover(item: pdfEditFlowData) { data in
            PdfFlowView(
                pdf: data.pdf,
                startAction: data.startAction,
                shouldShowCloseWarning: data.isNewPdf
            )
        }
    }

    func settingsView(showSettings: Binding<Bool>) -> some View {
        self.sheet(isPresented: showSettings) {
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSettings.wrappedValue = false }
                        }
                    }
            }
        }
    }

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
}

#Preview {
    MainTabView()
}
