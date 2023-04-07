//
//  MainTabView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import SwiftUI

enum TabItemIndex: Int {
    case archive
    case convert
    case settings
}

struct MainTabView: View {
    
    @State private var selection: Int = TabItemIndex.convert.rawValue
    
    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ArchiveView()
            }
            .tabItem {
                Label("File", image: "tab_archive")
            }
            .tag(TabItemIndex.archive.rawValue)
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Convert", image: "tab_conversion")
            }
            .tag(TabItemIndex.convert.rawValue)
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", image: "tab_settings")
            }
            .tag(TabItemIndex.settings.rawValue)
        }
        .background(ColorPalette.primaryBG)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
