//
//  MainCoordinator.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import SwiftUI
import Factory
import UniformTypeIdentifiers

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
    /// The paywall opened from the header, rather than by a document trying to
    /// leave. It lives here for the same reason as `settingsShow`: both shells
    /// show that button, and the presentation belongs to the shell above them.
    @Published var subscriptionShow: Bool = false
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
    /// A file another app just handed over, waiting for the Tools screen to
    /// import it. Staged in our own temporary directory — see `stagedCopy`.
    @Published private(set) var pendingExternalFile: URL? = nil
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

    /// Returns the file another app handed over, if any, and clears it so it is
    /// imported once.
    func consumePendingExternalFile() -> URL? {
        defer { self.pendingExternalFile = nil }
        return self.pendingExternalFile
    }

    /// A document opened from another app: "Copy to PDF Pro" in a share sheet, or
    /// an "Open in" menu. The Tools screen owns importing — the converter, the
    /// fallback prompt, the editor — so this only carries the file until that
    /// screen can take it, the same way `pendingToolAction` carries a tool.
    @MainActor
    private func handleIncomingFile(url: URL) {
        guard self.canImport(url) else { return }
        guard let staged = self.stagedCopy(of: url) else { return }
        self.cacheManager.onboardingShown = true
        self.rootView = .main
        self.tab = .tools
        self.pendingExternalFile = staged
    }

    /// Anything the app knows how to turn into a document. The system only offers
    /// us the types declared in `CFBundleDocumentTypes`, but a file can always
    /// arrive with an extension that promises more than it delivers.
    @MainActor
    private func canImport(_ url: URL) -> Bool {
        // A signed container is whatever is inside it. The envelope comes off in the
        // import path, and refusing it here would take back the whole point of
        // declaring the type: a `.p7m` arrives from Mail, and nowhere else.
        if SignedContainerUtility.isSignedContainer(url: url) { return true }
        if let type = UTType(filenameExtension: url.pathExtension),
           type.conforms(to: .pdf) || type.conforms(to: .image) {
            return true
        }
        return DocumentRenderUtility.canConvertFile(at: url)
    }

    /// Copies the file somewhere of our own before anything is done with it.
    ///
    /// Two reasons. A file the system drops in `Documents/Inbox` stays in the
    /// app's storage for good unless it is removed, and one opened in place lives
    /// behind a security-scoped door that is only open for this call.
    private func stagedCopy(of url: URL) -> URL? {
        // The unique name goes on the *folder*, and the file keeps the one it
        // arrived with. It used to be the other way round, and that name is not
        // private to this function: it is what the password prompt asks about,
        // what is sent to the conversion service, and what the saved document
        // ends up called. Opening a contract from the Finder produced a document
        // named "incoming-301ACA79-2AF1-4763-B0B4-5D9467590767".
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("incoming-\(UUID().uuidString)", isDirectory: true)
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            debugPrint(for: self, message: "Could not stage the incoming file. Error: \(error)")
            return nil
        }
        if url.pathComponents.contains("Inbox") {
            try? FileManager.default.removeItem(at: url)
        }
        return destination
    }
    
    func showPdfEditFlow(pdf: Pdf, startAction: PdfEditStartAction? = nil, isNewPdf: Bool) {
        self.pdfEditFlowData = PdfEditFlowData(pdf: pdf, startAction: startAction, isNewPdf: isNewPdf)
    }
    
    func closePdfEditFlow() {
        self.pdfEditFlowData = nil
    }
    
    @MainActor
    func handleOpenUrl(url: URL) {
        if url.isFileURL {
            self.handleIncomingFile(url: url)
        } else if let deeplink = Deeplink(fromCustomUrl: url) {
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
