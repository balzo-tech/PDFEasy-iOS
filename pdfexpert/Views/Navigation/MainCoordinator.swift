//
//  MainCoordinator.swift
//  PdfExpert
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
    /// The camera and everything it has produced. Deliberately its own tab
    /// rather than a tool: scanning is the one thing people open this app for
    /// while standing over a piece of paper, and it should never be more than
    /// one tap away. Raw value 4 keeps the earlier ones — and `debugInitialTab`
    /// — as they were.
    case scanner

    /// The tabs shown in the bar, in order. `search` is added separately
    /// because it carries the `.search` role.
    static var mainCases: [MainTab] { [.files, .tools, .scanner, .chat] }

    /// The same sections in the iPad sidebar, where search is a row like any
    /// other and belongs last. `allCases` would put the scanner after it, purely
    /// because of the order the cases happen to be declared in.
    static var sidebarCases: [MainTab] { Self.mainCases + [.search] }

    var title: String {
        switch self {
        case .files: return String(localized: "Files")
        case .tools: return String(localized: "Tools")
        case .chat: return String(localized: "ChatPDF")
        case .search: return String(localized: "Search")
        case .scanner: return String(localized: "Scanner")
        }
    }

    var systemImage: String {
        switch self {
        case .files: return "folder"
        case .tools: return "square.grid.2x2"
        case .chat: return "sparkles"
        case .search: return "magnifyingglass"
        case .scanner: return "doc.viewfinder"
        }
    }
}

/// A scanner opened with something specific in mind — today only Shortcuts
/// sends one. `nil` fields mean "leave it as the user left it".
struct ScanRequest: Equatable {
    var filter: ScanFilter? = nil
    var automaticShutter: Bool? = nil
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
    /// The document previewed in the iPad detail column, held as `Pdf.documentId`
    /// rather than as a `Pdf`: the archive hands out fresh values on every
    /// refresh and a stored struct would stop matching them.
    @Published var selectedDocumentId: String? = nil
    /// The tool described in the iPad detail column. Picking a tool there only
    /// selects it — it runs when the user confirms.
    @Published var selectedTool: PdfTool? = nil
    /// A tool requested from outside the Tools tab (the Files "New" button, the
    /// search results). The Tools screen owns every tool flow, so it picks this
    /// up and runs it once the tab is on screen.
    @Published var pendingToolAction: HomeAction? = nil
    /// The scanner, presented over whichever shell is on screen. It lives here
    /// rather than inside the Scanner tab because a widget, a shortcut or the
    /// Files "New" menu can all ask for it while another tab is showing.
    @Published var scanFlowShow: Bool = false
    /// How the caller wants the scanner set up. Shortcuts can ask for a filter
    /// or turn the automatic shutter off; a tap on the tab asks for nothing and
    /// gets whatever the user last used.
    private(set) var scanRequest: ScanRequest? = nil
    
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
        // debugStartScan=YES opens the scanner straight away. Paired with
        // debugScanPages it lands on the review screen, which is the only way to
        // see it on a simulator.
        if UserDefaults.standard.bool(forKey: "debugStartScan") {
            self.rootView = .main
            self.tab = .scanner
            self.scanFlowShow = true
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

    /// Opens the scanner, from wherever the request came from.
    func startScan(request: ScanRequest? = nil) {
        self.scanRequest = request
        self.tab = .scanner
        self.scanFlowShow = true
    }

    /// Returns the queued setup, if any, and clears it so it applies once.
    func consumeScanRequest() -> ScanRequest? {
        defer { self.scanRequest = nil }
        return self.scanRequest
    }

    /// Switches to the Tools tab and asks it to start `action`.
    func runTool(_ action: HomeAction) {
        // Scanning has a tab and a flow of its own; the catalog entry is a way
        // to find it, not a second implementation of it.
        guard action != .scan else {
            self.startScan()
            return
        }
        self.tab = .tools
        self.selectedTool = ToolCatalog.allTools.first { $0.action == action }
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
            $0.documentId == id || $0.filename == id
        }) else {
            return
        }
        self.selectedDocumentId = pdf.documentId
        self.showPdfEditFlow(pdf: pdf, isNewPdf: false)
    }
}

extension Container {
    var mainCoordinator: Factory<MainCoordinator> {
        self { MainCoordinator() }.singleton
    }
}
