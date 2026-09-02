//
//  ToolsView.swift
//  PdfExpert
//
//  The tool catalog. Replaces the old Home grid: the same actions, but reachable
//  by search or by family instead of by scrolling through six stacked sections.
//

import SwiftUI
import Factory
import PhotosUI

struct ToolsView: View {

    @ObservedObject var viewModel: HomeViewModel
    /// Bound by the split shell: there a tile only selects the tool, and the
    /// detail column explains it and starts it. On a phone there is no room for
    /// that step, so a tap runs the tool straight away.
    var selection: Binding<PdfTool?>? = nil

    @InjectedObject(\.mainCoordinator) private var mainCoordinator

    @State private var searchText: String = ""

    private static let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 158, maximum: 260), spacing: DS.Spacing.sm)
    ]

    private var tools: [PdfTool] { ToolCatalog.allTools }

    private var searchResults: [PdfTool] {
        let query = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return self.tools.filter { $0.matches(query: query) }
    }

    private var isSearching: Bool {
        !self.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            if self.isSearching {
                self.searchResultsView
            } else {
                self.catalogView
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(ColorPalette.background)
        .searchable(text: self.$searchText, prompt: Text("Search tools"))
        .animation(DS.Motion.smooth, value: self.isSearching)
        .onAppear() {
            self.viewModel.onAppear()
            self.runPendingToolActionIfNeeded()
            self.importPendingExternalFileIfNeeded()
            #if DEBUG
            self.runDebugToolIfNeeded()
            #endif
        }
        // A tool started from another tab (Files "New", search results) lands here.
        .onChange(of: self.mainCoordinator.pendingToolAction) { _, action in
            guard action != nil else { return }
            self.runPendingToolActionIfNeeded()
        }
        // A document another app handed over ("Copy to PDF Pro") lands here too:
        // importing is this screen's job, whoever asked for it.
        .onChange(of: self.mainCoordinator.pendingExternalFile) { _, url in
            guard url != nil else { return }
            self.importPendingExternalFileIfNeeded()
        }
        .formSheet(item: self.$viewModel.importOptionGroup) {
            OptionListView.getImportView(forImportOptionGroup: $0,
                                         importViewCallback: { self.viewModel.handleImportOption(importOption: $0) })
        }
        .filePicker(item: self.$viewModel.importFileOption, onPickedFiles: {
            self.viewModel.processPickedFileUrl($0.first)
        })
        // Camera / scanner modal flows, driven by a single activeSheet state machine.
        .fullScreenCover(item: self.$viewModel.activeSheet) { sheet in
            switch sheet {
            case .scanner:
                ScanFlowView(mode: .handOff, onPages: {
                    self.viewModel.convertScan(pages: $0)
                })
            case .camera:
                CameraView(model: Container.shared.cameraViewModel({ uiImage in
                    self.viewModel.convertImage(uiImage: uiImage)
                }))
            }
        }
        // Photo gallery picker
        .photosPicker(isPresented: self.$viewModel.imagePickerShow,
                      selection: self.$viewModel.imageSelections,
                      maxSelectionCount: HomeViewModel.maxPhotoSelectionCount,
                      matching: .images)
        .asyncView(asyncOperation: self.$viewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view })
        .showOfficeImportAlerts(coordinator: self.viewModel.officeImportCoordinator)
        .showSignedDocumentInfo(self.$viewModel.signedDocument,
                                onOpen: { self.viewModel.onSignedDocumentOpen(url: $0) })
        .showWebImportView(viewModel: self.viewModel.pdfWebImportViewModel)
        .showMarkdownImportView(viewModel: self.viewModel.pdfMarkdownImportViewModel)
        .showPermissionsView(viewModel: self.viewModel.pdfPermissionsViewModel)
        .showRedactView(viewModel: self.viewModel.pdfRedactViewModel)
        .showCompressView(viewModel: self.viewModel.pdfCompressViewModel)
        .showCompareView(viewModel: self.viewModel.pdfCompareViewModel)
        .showBackgroundRemovalView(viewModel: self.viewModel.backgroundRemovalViewModel)
        .showPassportPhotoView(viewModel: self.viewModel.passportPhotoViewModel)
        .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
        .addPasswordView(show: self.$viewModel.addPasswordShow,
                         addPasswordCallback: { self.viewModel.setPassword($0) })
        .addPasswordCompletedAlert(show: self.$viewModel.addPasswordCompletedShow,
                                   goToArchiveCallback: { self.viewModel.goToArchive() },
                                   sharePdfCallback: { self.viewModel.share() })
        .removePasswordCompletedAlert(show: self.$viewModel.removePasswordCompletedShow,
                                      goToArchiveCallback: { self.viewModel.goToArchive() },
                                      sharePdfCallback: { self.viewModel.share() })
        .showError(self.$viewModel.addPasswordError)
        .showError(self.$viewModel.removePasswordError)
        .showShareView(coordinator: self.viewModel.pdfShareCoordinator)
        .showMergeView(viewModel: self.viewModel.pdfMergeViewModel)
        .showSplitView(viewModel: self.viewModel.pdfSplitViewModel)
        .showExtractView(viewModel: self.viewModel.pdfExtractViewModel)
        .showExportView(viewModel: self.viewModel.pdfExportViewModel)
        .showConvertView(viewModel: self.viewModel.pdfConvertViewModel)
        .showAdvancedToolView(viewModel: self.viewModel.pdfAdvancedToolViewModel)
        .showReadView(viewModel: self.viewModel.pdfReadViewModel)
        .showUnlockView(viewModel: self.viewModel.pdfUnlockViewModel)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            self.viewModel.onDidBecomeActive()
        }
    }

    // MARK: - Catalog

    private var catalogView: some View {
        LazyVStack(alignment: .leading, spacing: DS.Spacing.xl, pinnedViews: []) {
            self.quickActionsSection
            ForEach(ToolCategory.allCases) { category in
                let tools = self.tools.filter { $0.category == category }
                if !tools.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeaderView(title: category.title, subtitle: category.subtitle)
                            .padding(.horizontal, DS.Spacing.md)
                        // A column narrow enough to hold one tile per row is a
                        // list, not a grid: the tiles would be enormous and each
                        // one would show a single tool.
                        if self.selection != nil {
                            VStack(spacing: DS.Spacing.xs) {
                                ForEach(tools) { tool in
                                    self.row(for: tool)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.md)
                        } else {
                            LazyVGrid(columns: Self.gridColumns, spacing: DS.Spacing.sm) {
                                ForEach(tools) { tool in
                                    self.tile(for: tool)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.md)
                        }
                    }
                }
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeaderView(title: String(localized: "Quick actions"))
                .padding(.horizontal, DS.Spacing.md)
            if UIDevice.hasDesktopClassLayout {
                // In a split view's middle column the five actions do not fit on
                // one line, and a row that scrolls sideways ends mid-icon with
                // no thumb to flick it along. Wrapping shows all of them.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: DS.Spacing.xs)],
                          alignment: .leading,
                          spacing: DS.Spacing.sm) {
                    self.quickActionTiles
                }
                .padding(.horizontal, DS.Spacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.xs) {
                        self.quickActionTiles
                    }
                    .padding(.horizontal, DS.Spacing.md)
                }
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder private var quickActionTiles: some View {
        ForEach(ToolUsageTracker.quickActions(from: self.tools)) { tool in
            QuickActionView(title: tool.title,
                            systemImage: tool.systemImage,
                            tint: tool.tint) {
                self.perform(tool)
            }
        }
    }

    // MARK: - Search

    @ViewBuilder private var searchResultsView: some View {
        let results = self.searchResults
        if results.isEmpty {
            ContentUnavailableView.search(text: self.searchText)
                .padding(.top, DS.Spacing.xxl)
        } else {
            LazyVStack(spacing: DS.Spacing.xs) {
                ForEach(results) { tool in
                    ToolRowView(title: tool.title,
                                subtitle: tool.subtitle,
                                systemImage: tool.systemImage,
                                tint: tool.tint,
                                isSelected: self.selection?.wrappedValue == tool) {
                        self.perform(tool)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    // MARK: - Actions

    private func tile(for tool: PdfTool) -> some View {
        ToolTileView(title: tool.title,
                     subtitle: tool.subtitle,
                     systemImage: tool.systemImage,
                     tint: tool.tint,
                     isSelected: self.selection?.wrappedValue == tool) {
            self.perform(tool)
        }
    }

    private func row(for tool: PdfTool) -> some View {
        ToolRowView(title: tool.title,
                    subtitle: tool.subtitle,
                    systemImage: tool.systemImage,
                    tint: tool.tint,
                    isSelected: self.selection?.wrappedValue == tool) {
            self.perform(tool)
        }
    }

    private func perform(_ tool: PdfTool) {
        self.searchText = ""
        if let selection = self.selection {
            selection.wrappedValue = tool
        } else {
            ToolUsageTracker.registerUse(of: tool.action)
            self.viewModel.performHomeAction(tool.action)
        }
    }

    /// Runs an action queued by another tab. Deferred to the next runloop so the
    /// tool's sheet is presented on a screen that is already on stage.
    private func runPendingToolActionIfNeeded() {
        guard let action = self.mainCoordinator.consumePendingToolAction() else { return }
        DispatchQueue.main.async {
            ToolUsageTracker.registerUse(of: action)
            self.viewModel.performHomeAction(action)
        }
    }

    /// Imports a file another app handed over. Deferred for the same reason as
    /// the tool above: the conversion can put an alert or the editor on screen,
    /// and this screen may still be arriving.
    private func importPendingExternalFileIfNeeded() {
        guard let url = self.mainCoordinator.consumePendingExternalFile() else { return }
        DispatchQueue.main.async {
            self.viewModel.importExternalFile(url: url)
        }
    }

    #if DEBUG
    /// Opens a tool on the bundled test document, so its sheet can be inspected on a
    /// simulator where the file picker cannot be driven:
    ///   xcrun simctl spawn booted defaults write <bundle-id> debugRunTool -string compress
    /// Values: `compress`, `compare`, `redact`, `permissions`, `split`, `markdown`,
    /// `sort`, `read`, `editor`, `background`, `passport`, `passport-sheet`. The premium ones also need `debugPremium -bool YES`,
    /// or the paywall opens instead of the tool.
    private func runDebugToolIfNeeded() {
        guard let tool = UserDefaults.standard.string(forKey: "debugRunTool"),
              let pdf = K.Test.DebugPdf else { return }
        DispatchQueue.main.async {
            switch tool {
            case "compress":
                self.viewModel.pdfCompressViewModel.run(pdf: pdf, onCompleted: nil)
            case "compare":
                // Two synthetic documents: the picker cannot be driven from here.
                self.viewModel.pdfCompareViewModel.debugRunWithSampleDocuments()
            case "redact":
                self.viewModel.pdfRedactViewModel.run(pdf: pdf, onCompleted: nil)
            case "permissions":
                self.viewModel.pdfPermissionsViewModel.run(pdf: pdf, onCompleted: nil)
            case "split":
                // Opens the page-range editor, which is the screen worth looking at.
                self.viewModel.pdfSplitViewModel.split(pdf: pdf, onSplitCompleted: nil)
            case "markdown":
                self.viewModel.pdfMarkdownImportViewModel.start()
            case "sort":
                // The sorter belongs to Merge, which needs several documents picked
                // by hand; three copies of the test one stand in for them.
                self.viewModel.pdfMergeViewModel.toBeSortedPdfs = [pdf, pdf, pdf]
                self.viewModel.pdfMergeViewModel.showPdfSorter = true
            case "read":
                self.viewModel.pdfReadViewModel.read(pdf: pdf)
            case "background":
                // A drawn photograph: the picker cannot be driven from here, and
                // on a simulator the cut-out is a placeholder oval anyway.
                self.viewModel.backgroundRemovalViewModel.run(image: Self.debugPhotograph(),
                                                              onCreatePdf: nil)
            case "passport", "passport-sheet":
                self.viewModel.passportPhotoViewModel.run(image: Self.debugPhotograph(),
                                                          onCreatePdf: nil)
                // `run` resets the tool before it starts, so the output has to be
                // chosen after it rather than before.
                if tool == "passport-sheet" {
                    self.viewModel.passportPhotoViewModel.output = .sheet
                }
            case "editor":
                // The editor on a document nobody has named yet: `Pdf(data:)` keeps
                // the generated filename, which is what the name suggestion needs.
                if let data = K.Test.DebugPdfDocumentData, let unnamed = Pdf(data: data) {
                    self.mainCoordinator.showPdfEditFlow(pdf: unnamed, isNewPdf: true)
                }
            default:
                break
            }
        }
    }

    /// A stand-in photograph for `debugRunTool background`.
    private static func debugPhotograph() -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemOrange.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 180, y: 180, width: 540, height: 840))
        }
    }
    #endif
}

extension View {

    @ViewBuilder func addPasswordCompletedAlert(show: Binding<Bool>,
                                                goToArchiveCallback: @escaping () -> (),
                                                sharePdfCallback: @escaping () -> ()) -> some View {
        self.alert("PDF Protected!", isPresented: show, actions: {
            Button("Go to files", action: goToArchiveCallback)
            Button("Share pdf", action: sharePdfCallback)
        }, message: {
            Text("Your pdf has been successfully protected")
        })
    }

    @ViewBuilder func removePasswordCompletedAlert(show: Binding<Bool>,
                                                   goToArchiveCallback: @escaping () -> (),
                                                   sharePdfCallback: @escaping () -> ()) -> some View {
        self.alert("PDF Unlocked!", isPresented: show, actions: {
            Button("Go to files", action: goToArchiveCallback)
            Button("Share pdf", action: sharePdfCallback)
        }, message: {
            Text("Your pdf has been successfully unlocked")
        })
    }
}

extension ImportOptionGroup: FormSheetItem {
    var viewSize: CGSize {
        switch self {
        case .image: return CGSize(width: 400.0, height: 250.0)
        case .fileAndScan: return CGSize(width: 400.0, height: 220.0)
        }
    }
}

#Preview {
    NavigationStack {
        ToolsView(viewModel: Container.shared.homeViewModel())
            .navigationTitle("Tools")
    }
}
