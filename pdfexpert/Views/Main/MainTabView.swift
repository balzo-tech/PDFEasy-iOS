//
//  MainTabView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import SwiftUI

fileprivate enum MainTab: Int, CaseIterable {
    case archive
    case home
    case chatPdf
    case settings
    
    var name: String {
        switch self {
        case .archive: return "File"
        case .home: return "Explore"
        case .chatPdf: return "ChatPDF"
        case .settings: return "Settings"
        }
    }
    
    var imageName: String {
        switch self {
        case .archive: return "tab_archive"
        case .home: return "tab_home"
        case .chatPdf: return "tab_chat_pdf"
        case .settings: return "tab_settings"
        }
    }
}

struct MainTabView: View {
    
    @State private var selection: Int = MainTab.home.rawValue
    
    var body: some View {
        TabView(selection: $selection) {
            ForEach(MainTab.allCases, id:\.self) { tab in
                NavigationStack {
                    self.getRootView(forTab: tab)
                        .navigationTitle(tab.name)
                        .toolbarBackground(ColorPalette.secondaryBG, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                }
                .tabItem {
                    Label(tab.name, image: tab.imageName)
                }
                .tag(tab.rawValue)
            }
        }
        .background(ColorPalette.primaryBG)
    }
    
    @MainActor @ViewBuilder private func getRootView(forTab tab: MainTab) -> some View {
        switch tab {
        case .archive: ArchiveView()
        case .home: HomeView()
        case .chatPdf: ChatPdfSelectionView()
        case .settings: SettingsView()
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
