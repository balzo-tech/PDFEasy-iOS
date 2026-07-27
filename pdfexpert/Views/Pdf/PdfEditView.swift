//
//  PdfEditView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//
//  The document editor. The page fills the screen; under it sit the two bars
//  that matter — what you can do to *this page*, and the four edits people reach
//  for constantly — and everything that acts on the whole document is behind the
//  wrench, in a panel that looks like the Tools tab because it is describing the
//  same tools.
//
//  A tool that asks a question is now pushed onto the editor's own navigation
//  stack instead of covering it: the document stays one back-swipe away, and on
//  a wide window it stays visible beside the form. The tools that are a flow of
//  their own — import, configure, produce a second document — still own their
//  presentation; see `EditorTool.presentation`.
//
//  Given a wide window it reflows: the page thumbnails become a rail down the
//  left where a dozen of them are visible at once instead of three, and the
//  primary edits move up into the toolbar, since a bar floating over the page
//  only makes sense when the page is the whole screen.
//

import SwiftUI
import Factory
import PhotosUI

struct PdfEditView: View {

    fileprivate static let cellSide: CGFloat = 64.0
    fileprivate static let selectedCellBorderWidth: CGFloat = 3.0
    /// Wide enough for a readable page preview plus its number, narrow enough to
    /// leave the page itself the bulk of the window.
    fileprivate static let railWidth: CGFloat = 116.0
    fileprivate static let railCellSize = CGSize(width: 84, height: 110)

    @StateObject var viewModel: PdfEditViewModel
    /// What the close button does. The editor does not know whether closing it
    /// means losing work — the flow that opened it does.
    var onClose: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showingImageInputPicker = false
    @State private var showingDeleteConfermation = false

    @State private var draggedPageId: EditorPage.ID? = nil

    private var isWideLayout: Bool { self.horizontalSizeClass == .regular }

    /// Asked of the document, not of the images of it: the pages are drawn in
    /// the background and arrive one at a time, so "how many pages" is known
    /// well before "what do they look like".
    private var hasPages: Bool { self.viewModel.pageCount > 0 }

    var body: some View {
        NavigationStack(path: self.$viewModel.path) {
            self.editor
                .navigationDestination(for: EditorRoute.self) { route in
                    EditorDestinationView(route: route, viewModel: self.viewModel)
                }
        }
    }

    private var editor: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()
            if self.isWideLayout {
                HStack(spacing: 0) {
                    if self.viewModel.pages.count > 1 {
                        self.pageRailView
                        Divider()
                    }
                    self.pdfView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    self.pdfView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if self.viewModel.pages.count > 1 {
                        self.pageListView
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if let suggestion = self.viewModel.suggestedFilename {
                self.nameSuggestionBar(suggestion)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if self.hasPages {
                self.bottomBars
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(self.$viewModel.pdfFilename)
        .ignoresSafeArea(.keyboard)
        .toolbar { self.toolbarContent }
        .onAppear(perform: self.viewModel.onAppear)
        .sheet(isPresented: self.$viewModel.toolPanelShow) {
            PdfEditToolPanel(isPasswordSet: self.viewModel.pdf.password != nil,
                             pageCount: self.viewModel.pageCount,
                             onTool: { self.perform($0) })
        }
        .filePicker(isPresented: self.$viewModel.filePickerShow,
                    fileTypes: K.Misc.ImportFileTypesForAddPage,
                    onPickedFiles: {
            // Callback is called on modal dismiss, thus we can assign and convert in a row
            self.viewModel.urlToFileToConvert = $0.first
            self.viewModel.convert()
        })
        .photosPicker(isPresented: self.$viewModel.imagePickerShow,
                      selection: self.$viewModel.imageSelection,
                      matching: .images)
        // What is left of the covers: the tools that are direct manipulation of
        // the page, and the two ways of photographing a new one.
        .fullScreenCover(item: self.$viewModel.activeSheet) { sheet in
            self.cover(for: sheet)
        }
        .pdfEditAlerts(viewModel: self.viewModel)
        // Page turning by keyboard. It used to hang off the "…" menu, which is
        // gone; the shortcuts are worth keeping on an iPad with a keyboard, so
        // they live on two buttons that are present but invisible.
        .background {
            Group {
                Button {
                    self.goToPage(self.viewModel.pdfCurrentPageIndex - 1)
                } label: { Color.clear }
                    .keyboardShortcut(.upArrow, modifiers: [.command])
                Button {
                    self.goToPage(self.viewModel.pdfCurrentPageIndex + 1)
                } label: { Color.clear }
                    .keyboardShortcut(.downArrow, modifiers: [.command])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
        .confirmationDialog(Text("Delete this page?"),
                            isPresented: self.$showingDeleteConfermation,
                            titleVisibility: .visible) {
            Button("Delete this page", role: .destructive) {
                self.showingDeleteConfermation = false
                withAnimation(DS.Motion.smooth) {
                    self.viewModel.deleteCurrentPage()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(Text("Choose your source"),
                            isPresented: self.$showingImageInputPicker,
                            titleVisibility: .visible) {
            Button("Photo Gallery") { self.viewModel.openGallery() }
            Button("Camera") { self.viewModel.openCamera() }
            Button("File") { self.viewModel.openFilePicker() }
            Button("Scan") { self.viewModel.openScanner() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Covers

    @ViewBuilder private func cover(for sheet: PdfEditViewModel.ActiveSheet) -> some View {
        switch sheet {
        case .camera:
            CameraView(model: Container.shared.cameraViewModel({ uiImage in
                self.viewModel.activeSheet = nil
                self.viewModel.imageToConvert = uiImage
            })).onDisappear { self.viewModel.convert() }
        case .scanner:
            ScanFlowView(mode: .handOff, onPages: {
                self.viewModel.activeSheet = nil
                self.viewModel.scannedPages = $0
            }).onDisappear { self.viewModel.convert() }
        case .signature:
            let inputParameter = PdfSignatureViewModel
                .InputParameter(pdf: self.viewModel.pdf,
                                currentPageIndex: self.viewModel.pdfCurrentPageIndex,
                                onConfirm: { self.viewModel.updatePdf(pdf: $0) })
            PdfSignatureView(viewModel: Container.shared.pdfSignatureViewModel(inputParameter))
        case .fillForm:
            let inputParameter = PdfFillFormViewModel
                .InputParameter(pdf: self.viewModel.pdf,
                                currentPageIndex: self.viewModel.pdfCurrentPageIndex,
                                onConfirm: { self.viewModel.updatePdf(pdf: $0) })
            PdfFillFormView(viewModel: Container.shared.pdfFillFormViewModel(inputParameter))
        case .fillWidget:
            let inputParameter = PdfFillWidgetViewModel
                .InputParameter(pdf: self.viewModel.pdf,
                                currentPageIndex: self.viewModel.pdfCurrentPageIndex,
                                onConfirm: { self.viewModel.updatePdf(pdf: $0) })
            PdfFillWidgetView(viewModel: Container.shared.pdfFillWidgetViewModel(inputParameter))
        }
    }

    // MARK: - Pages

    @ViewBuilder var pdfView: some View {
        if self.viewModel.pages.isEmpty, self.viewModel.isPreparingPages {
            self.preparingView
        } else if self.viewModel.pages.count > 0 {
            TabView(selection: self.$viewModel.pdfCurrentPageIndex) {
                ForEach(Array(self.viewModel.pages.enumerated()), id: \.element.id) { (pageIndex, page) in
                    // Full size if it has been drawn, the thumbnail scaled up if
                    // not: only the pages around this one are kept at full size,
                    // so a fast swipe can outrun the drawing by a moment.
                    let drawn = self.viewModel.pageImage(at: pageIndex)
                    PageImage(image: drawn ?? page.thumbnail, isSharp: drawn != nil)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .tag(pageIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .overlay(alignment: .top) {
                self.pageCounterBadge
            }
        } else {
            self.emptyView
        }
    }

    private var pageCounterBadge: some View {
        Text("\(self.viewModel.pdfCurrentPageIndex + 1) of \(self.viewModel.pageCount)")
            .font(forCategory: .caption1)
            .foregroundStyle(ColorPalette.textPrimary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 6)
            .floatingGlassCapsule(interactive: false)
            .padding(.top, DS.Spacing.xs)
            .animation(DS.Motion.quick, value: self.viewModel.pdfCurrentPageIndex)
    }

    /// The first moments on a long document: the pages are being drawn, and the
    /// editor says so instead of showing the "you have no pages" screen, which
    /// is what an empty list used to mean.
    private var preparingView: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
            Text("Preparing your pages…")
                .font(forCategory: .body3)
                .foregroundStyle(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var emptyView: some View {
        ContentUnavailableView {
            Label("You have no pages", systemImage: "doc")
        } description: {
            Text("Add a page from your photos, the camera, a file or a scan.")
        } actions: {
            PrimaryActionButton(title: String(localized: "Add a new page"), systemImage: "plus") {
                self.showingImageInputPicker = true
            }
            .frame(maxWidth: 260)
        }
    }

    /// The wide-window counterpart of `pageListView`. Vertical, because pages
    /// are taller than they are wide and a column of them shows a dozen at once
    /// where the horizontal strip shows three.
    var pageRailView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: DS.Spacing.xs) {
                    ForEach(Array(self.viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        Button(action: {
                            withAnimation(DS.Motion.quick) {
                                self.viewModel.pdfCurrentPageIndex = index
                            }
                        }) {
                            VStack(spacing: 4) {
                                self.getThumbnailCell(page: page)
                                    .applyRailCellStyle(highlight: index == self.viewModel.pdfCurrentPageIndex)
                                Text("\(index + 1)")
                                    .font(forCategory: .caption2)
                                    .foregroundStyle(index == self.viewModel.pdfCurrentPageIndex
                                                     ? ColorPalette.accent
                                                     : ColorPalette.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                        .id(index)
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
            }
            .onChange(of: self.viewModel.pdfCurrentPageIndex) { _, index in
                guard self.isScrollToAvailable else { return }
                withAnimation(DS.Motion.quick) { proxy.scrollTo(index, anchor: .center) }
            }
        }
        .frame(width: Self.railWidth)
        .background(ColorPalette.surface)
    }

    var pageListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DS.Spacing.xs) {
                ForEach(Array(self.viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    Button(action: {
                        withAnimation(DS.Motion.quick) {
                            self.viewModel.pdfCurrentPageIndex = index
                        }
                    }) {
                        VStack(spacing: 4) {
                            self.getThumbnailCell(page: page)
                                .applyCellStyle(highlight: index == self.viewModel.pdfCurrentPageIndex)
                            Text("\(index + 1)")
                                .font(forCategory: .caption2)
                                .foregroundStyle(index == self.viewModel.pdfCurrentPageIndex
                                                 ? ColorPalette.accent
                                                 : ColorPalette.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
        }
        .scrollClipDisabled()
        .frame(height: Self.cellSide + 34)
    }

    // MARK: - Bars

    /// Page actions first, then the frequent edits: the closer a control is to
    /// the page, the more it is about that page.
    @ViewBuilder private var bottomBars: some View {
        VStack(spacing: DS.Spacing.xs) {
            PdfEditPageBar(canReorder: self.viewModel.pageCount > 1,
                           onTool: { self.perform($0) })
            if !self.isWideLayout {
                PdfEditPrimaryBar(onTool: { self.perform($0) })
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xs)
        .readableColumn()
        // Every one of these edits the document and the two lists of images in
        // step, so none of them can run until there is one image per page.
        .disabled(!self.viewModel.canEditPages)
        .opacity(self.viewModel.canEditPages ? 1 : 0.5)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        if let onClose = self.onClose {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Label("Close", systemImage: "xmark")
                }
            }
        }
        if self.isWideLayout, self.hasPages {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ForEach(PdfEditPrimaryBar.tools) { tool in
                    Button {
                        self.perform(tool)
                    } label: {
                        Label(tool.title, systemImage: tool.systemImage)
                    }
                    .disabled(!self.viewModel.canEditPages)
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                self.viewModel.toolPanelShow = true
            } label: {
                Label("Tools", systemImage: "wrench.and.screwdriver")
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                self.viewModel.save()
            } label: {
                Label("Save PDF", systemImage: "checkmark")
            }
            .buttonStyle(.glassProminent)
            .tint(ColorPalette.accent)
            .keyboardShortcut("s", modifiers: [.command])
        }
    }

    private func goToPage(_ index: Int) {
        guard index >= 0, index < self.viewModel.pages.count else { return }
        withAnimation(DS.Motion.quick) { self.viewModel.pdfCurrentPageIndex = index }
    }

    /// Every tool goes through here. The two that need a question asked first
    /// are asked here; the rest are the view model's business.
    private func perform(_ tool: EditorTool) {
        switch tool {
        case .addPage:
            self.showingImageInputPicker = true
        case .deletePage:
            self.showingDeleteConfermation = true
        default:
            self.viewModel.run(tool)
        }
    }

    /// The name the document proposes for itself. A bar, not a rename: the app
    /// reads a title off the page, the user accepts it or waves it away, and doing
    /// nothing leaves the document named exactly as it was.
    private func nameSuggestionBar(_ suggestion: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ColorPalette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Suggested name")
                    .font(forCategory: .caption2)
                    .foregroundStyle(ColorPalette.textSecondary)
                Text(suggestion)
                    .font(forCategory: .body3)
                    .foregroundStyle(ColorPalette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Use") {
                withAnimation(DS.Motion.quick) { self.viewModel.useSuggestedFilename() }
            }
            .buttonStyle(.glassProminent)
            .tint(ColorPalette.accent)
            Button {
                withAnimation(DS.Motion.quick) { self.viewModel.dismissFilenameSuggestion() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ColorPalette.textSecondary)
                    .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(.leading, DS.Spacing.sm)
        .padding(.vertical, 6)
        .floatingGlass(radius: DS.Radius.control)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.xs)
        .readableColumn()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    func getThumbnailCell(page: EditorPage) -> some View {
        PageThumbnail(image: page.thumbnail)
            .onDrag {
                self.draggedPageId = page.id
                return NSItemProvider()
            }
            .onDrop(of: [.image],
                    delegate: PdfEditDropViewDelegate(destinationId: page.id,
                                                      draggedId: self.$draggedPageId,
                                                      viewModel: self.viewModel))
    }
}

/// A page's small image, or a placeholder for a page that would not draw. The
/// thumbnails arrive one at a time and a page that fails to draw still gets an
/// entry, so "no image" is a state the strip has to be able to show.
struct PageThumbnail: View {

    let image: UIImage?

    var body: some View {
        if let image = self.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ColorPalette.surface
                .overlay {
                    Image(systemName: "doc")
                        .font(.system(size: 15))
                        .foregroundStyle(ColorPalette.textTertiary)
                }
        }
    }
}

/// The page in the pager: the full-size drawing when there is one, the thumbnail
/// stretched to fill the same space when there is not. Same frame either way, so
/// the page does not jump when the sharp version arrives.
struct PageImage: View {

    let image: UIImage?
    let isSharp: Bool

    var body: some View {
        if let image = self.image {
            Image(uiImage: image)
                .resizable()
                .interpolation(self.isSharp ? .high : .medium)
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

fileprivate extension View {

    func applyCellStyle(highlight: Bool) -> some View {
        self
            .frame(width: PdfEditView.cellSide, height: PdfEditView.cellSide)
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(highlight ? ColorPalette.accent : ColorPalette.separator,
                                  lineWidth: highlight ? PdfEditView.selectedCellBorderWidth : 0.5)
            }
    }

    /// Same treatment as `applyCellStyle`, at page proportions: the rail has the
    /// height to show a thumbnail that is actually recognisable.
    func applyRailCellStyle(highlight: Bool) -> some View {
        self
            .frame(width: PdfEditView.railCellSize.width, height: PdfEditView.railCellSize.height)
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(highlight ? ColorPalette.accent : ColorPalette.separator,
                                  lineWidth: highlight ? PdfEditView.selectedCellBorderWidth : 0.5)
            }
    }
}

struct PdfEditView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            if let pdf = K.Test.DebugPdf {
                let inputParameter = PdfEditViewModel.InputParameter(pdf: pdf,
                                                                     startAction: nil,
                                                                     shouldShowCloseWarning: .constant(true))
                AnyView(PdfEditView(viewModel: Container.shared.pdfEditViewModel(inputParameter)))
            } else {
                AnyView(Spacer())
            }
        }
    }
}

fileprivate struct PdfEditDropViewDelegate: DropDelegate {

    let destinationId: EditorPage.ID
    @Binding var draggedId: EditorPage.ID?
    var viewModel: PdfEditViewModel

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        self.draggedId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        // Swap Items. By page identity: two pages of a scan can be the same
        // picture, and looking them up by image found whichever came first.
        guard let draggedId = self.draggedId,
              let fromIndex = self.viewModel.pages.firstIndex(where: { $0.id == draggedId }),
              let toIndex = self.viewModel.pages.firstIndex(where: { $0.id == self.destinationId }),
              fromIndex != toIndex else {
            return
        }
        self.viewModel.handlePageReordering(fromIndex: fromIndex, toIndex: toIndex)
    }
}
