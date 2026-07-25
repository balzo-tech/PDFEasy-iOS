//
//  MainCoordinator.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import SwiftUI
import Factory

enum MainTab: Int, CaseIterable, Hashable {
    /// Saved documents — the app opens here.
    case files
    /// The tool catalog.
    case tools
    /// ChatPDF.
    case chat
    /// Cross-content search (documents + tools), presented with the system's
    /// search tab role.
    case search

    /// The tabs shown in the bar, in order. `search` is added separately
    /// because it carries the `.search` role.
    static var mainCases: [MainTab] { [.files, .tools, .chat] }

    var title: String {
        switch self {
        case .files: return String(localized: "Files")
        case .tools: return String(localized: "Tools")
        case .chat: return String(localized: "ChatPDF")
        case .search: return String(localized: "Search")
        }
    }

    var systemImage: String {
        switch self {
        case .files: return "folder"
        case .tools: return "square.grid.2x2"
        case .chat: return "sparkles"
        case .search: return "magnifyingglass"
        }
    }
}

struct PdfEditFlowData: Hashable, Identifiable {
    
    var id: Self { return self }
    
    let pdf: Pdf
    let startAction: PdfEditStartAction?
    let isNewPdf: Bool
}

class MainCoordinator: ObservableObject {
    
    enum RootView {
        case onboarding
        case main
    }
    
    enum Route: Hashable {
        case onboarding
    }
    
    @Published var rootView: RootView = .onboarding
    @Published var tab: MainTab = MainTab.files
    @Published var path: [Route] = []
    @Published var pdfEditFlowData: PdfEditFlowData? = nil
    @Published var settingsShow: Bool = false
    /// A tool requested from outside the Tools tab (the Files "New" button, the
    /// search results). The Tools screen owns every tool flow, so it picks this
    /// up and runs it once the tab is on screen.
    @Published var pendingToolAction: HomeAction? = nil
    
    @Injected(\.cacheManager) private var cacheManager
    @Injected(\.reviewFlow) var reviewFlow
    @Injected(\.repository) private var repository
    
    init() {
        if self.cacheManager.onboardingShown {
            self.rootView = .main
        } else {
            self.rootView = .onboarding
        }
        #if DEBUG
        // Lets a debug build launch straight into a given tab:
        //   xcrun simctl spawn booted defaults write <bundle-id> debugInitialTab -int 1
        // Handy for the simulator, where tapping through is not always possible.
        if let raw = UserDefaults.standard.object(forKey: "debugInitialTab") as? Int,
           let tab = MainTab(rawValue: raw) {
            self.rootView = .main
            self.tab = tab
        }
        if UserDefaults.standard.bool(forKey: "debugShowSettings") {
            self.rootView = .main
            self.settingsShow = true
        }
        #endif
    }
    
    func showOnboarding() {
        self.path.append(.onboarding)
    }
    
    func goToMain() {
        self.rootView = .main
    }
    
    func goToArchive() {
        self.tab = MainTab.files
    }

    /// Switches to the Tools tab and asks it to start `action`.
    func runTool(_ action: HomeAction) {
        self.tab = .tools
        self.pendingToolAction = action
    }

    /// Returns the queued tool action, if any, and clears it so it runs once.
    func consumePendingToolAction() -> HomeAction? {
        defer { self.pendingToolAction = nil }
        return self.pendingToolAction
    }
    
    func showPdfEditFlow(pdf: Pdf, startAction: PdfEditStartAction? = nil, isNewPdf: Bool) {
        self.pdfEditFlowData = PdfEditFlowData(pdf: pdf, startAction: startAction, isNewPdf: isNewPdf)
    }
    
    func closePdfEditFlow() {
        self.pdfEditFlowData = nil
    }
    
    func handleOpenUrl(url: URL) {
        if let deeplink = Deeplink(fromCustomUrl: url) {
            self.handleDeeplink(deeplink: deeplink)
        }
    }
    
    func startReview() {
        self.reviewFlow.startFlowIfNeeded()
    }
    
    private func handleDeeplink(deeplink: Deeplink) {
        switch deeplink {
        case .chatPdf:
            self.cacheManager.onboardingShown = true
            self.rootView = .main
            self.tab = .chat
        case .tab(let tab):
            self.cacheManager.onboardingShown = true
            self.rootView = .main
            self.tab = tab
        case .document(let id):
            self.cacheManager.onboardingShown = true
            self.rootView = .main
            self.tab = .files
            self.openDocument(withId: id)
        case .tool(let identifier):
            guard let action = HomeAction(identifier: identifier) else { return }
            self.cacheManager.onboardingShown = true
            self.rootView = .main
            self.runTool(action)
        }
    }

    /// Opens a saved document by its Core Data object URI, as handed over by the
    /// widget. Falls back to just showing the archive when the document is gone.
    private func openDocument(withId id: String) {
        guard let pdf = (try? self.repository.loadPdfs())?.first(where: {
            $0.storeId?.uriRepresentation().absoluteString == id || $0.filename == id
        }) else {
            return
        }
        self.showPdfEditFlow(pdf: pdf, isNewPdf: false)
    }
}

extension Container {
    var mainCoordinator: Factory<MainCoordinator> {
        self { MainCoordinator() }.singleton
    }
}
