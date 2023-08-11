//
//  MainTabView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import SwiftUI
import Factory

fileprivate extension MainTab {
    
    var name: String {
        switch self {
        case .archive: return "File"
        case .home: return "Explore"
        case .chatPdf: return "ChatPDF"
        }
    }
    
    var imageName: String {
        switch self {
        case .archive: return "tab_archive"
        case .home: return "tab_home"
        case .chatPdf: return "tab_chat_pdf"
        }
    }
}

struct MainTabView: View {
    
    @InjectedObject(\.mainCoordinator) var mainCoordinator
    
    var body: some View {
        TabView(selection: self.$mainCoordinator.tab) {
            ForEach(MainTab.allCases, id:\.self) { tab in
                NavigationStack {
                    self.getRootView(forTab: tab)
                        .navigationTitle(tab.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(ColorPalette.secondaryBG, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .settingsButton(showSettings: self.$mainCoordinator.settingsShow)
                }
                .tabItem {
                    Label(tab.name, image: tab.imageName)
                }
                .tag(tab.rawValue)
            }
        }
        .background(ColorPalette.primaryBG)
        .pdfEditFlowView(pdfEditFlowData: self.$mainCoordinator.pdfEditFlowData)
        .settingsView(showSettings: self.$mainCoordinator.settingsShow)
    }
    
    @MainActor @ViewBuilder private func getRootView(forTab tab: MainTab) -> some View {
        switch tab {
        case .archive: ArchiveView()
        case .home: HomeView()
        case .chatPdf: ChatPdfSelectionView()
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
        self.fullScreenCover(isPresented: showSettings) {
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("Settings")
                    .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                        showSettings.wrappedValue = false
                    })
            }
            .background(ColorPalette.primaryBG)
        }
    }
    
    func settingsButton(showSettings: Binding<Bool>) -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings.wrappedValue = true }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
