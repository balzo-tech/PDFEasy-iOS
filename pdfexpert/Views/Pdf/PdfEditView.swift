//
//  PdfEditView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//
//  The document editor. The page fills the screen, the four things people do
//  most often live in a glass bar floating over it, and everything else is one
//  grouped menu away — the old flat list of fourteen options in a form sheet
//  made them all look equally likely.
//
//  Given a wide window it reflows: the page thumbnails become a rail down the
//  left where a dozen of them are visible at once instead of three, and the four
//  frequent edits move up into the toolbar, since a bar floating over the page
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showingImageInputPicker = false
    @State private var showingDeleteConfermation = false

    @State private var draggedImage: UIImage? = nil

    private var isWideLayout: Bool { self.horizontalSizeClass == .regular }

    private var hasPages: Bool { self.viewModel.pageImages.count > 0 }

    var body: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()
            if self.isWideLayout {
                HStack(spacing: 0) {
                    if self.viewModel.pdfThumbnails.count > 1 {
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
                    if self.viewModel.pdfThumbnails.count > 1 {
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
            // On a wide window these four live in the toolbar instead: a bar
            // floating over the page only reads as "above the content" when the
            // page is the whole screen.
            if self.hasPages, !self.isWideLayout {
                self.actionBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(self.$viewModel.pdfFilename)
        .ignoresSafeArea(.keyboard)
        .toolbar {
            if self.isWideLayout, self.hasPages {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ForEach(PrimaryEdit.allCases) { edit in
                        Button {
                            self.perform(edit)
                        } label: {
                            Label(edit.title, systemImage: edit.systemImage)
                        }
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                self.moreMenu
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
        .onAppear(perform: self.viewModel.onAppear)
        // File picker
        .filePicker(isPresented: self.$viewModel.filePickerShow,
                    fileTypes: K.Misc.ImportFileTypesForAddPage,
                    onPickedFiles: {
            // Callback is called on modal dismiss, thus we can assign and convert in a row
            self.viewModel.urlToFileToConvert = $0.first
            self.viewModel.convert()
        })
        // Photo gallery picker
        .photosPicker(isPresented: self.$viewModel.imagePickerShow,
                      selection: self.$viewModel.imageSelection,
                      matching: .images)
        // Camera / scanner / signature / fill-form / fill-widget modal flows,
        // driven by a single activeSheet state machine.
        .fullScreenCover(item: self.$viewModel.activeSheet) { sheet in
            switch sheet {
            case .camera:
                CameraView(model: Container.shared.cameraViewModel({ uiImage in
                    self.viewModel.activeSheet = nil
                    self.viewModel.imageToConvert = uiImage
                })).onDisappear { self.viewModel.convert() }
            case .scanner:
                ScannerView(onScannerResult: {
                    self.viewModel.activeSheet = nil
                    self.viewModel.scannerResult = $0
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
            case .pageNumbers:
                let inputParameter = PdfPageNumberViewModel
                    .InputParameter(pdf: self.viewModel.pdf,
                                    onConfirm: { self.viewModel.updatePdf(pdf: $0) })
                PdfPageNumberView(viewModel: Container.shared.pdfPageNumberViewModel(inputParameter))
            case .watermark:
                let inputParameter = PdfWatermarkViewModel
                    .InputParameter(pdf: self.viewModel.pdf,
                                    onConfirm: { self.viewModel.updatePdf(pdf: $0) })
                PdfWatermarkView(viewModel: Container.shared.pdfWatermarkViewModel(inputParameter))
            case .metadata:
                let inputParameter = PdfMetadataViewModel
                    .InputParameter(pdf: self.viewModel.pdf,
                                    onConfirm: { self.viewModel.applyMetadata(pdf: $0) })
                PdfMetadataView(viewModel: Container.shared.pdfMetadataViewModel(inputParameter))
            }
        }
        .showCompressView(viewModel: self.viewModel.pdfCompressViewModel)
        .asyncView(asyncOperation: self.$viewModel.asyncPdf,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$viewModel.asyncOcr,
                   loadingView: { AnimationType.pdf.view })
        .asyncView(asyncOperation: self.$viewModel.asyncCleanup,
                   loadingView: { AnimationType.pdf.view })
        .alert(String(localized: "Done"), isPresented: self.$viewModel.cleanupAlertShow, actions: {
            Button("Ok", role: .cancel, action: {})
        }, message: {
            Text(self.viewModel.cleanupAlertMessage)
        })
        .asyncView(asyncOperation: self.$viewModel.asyncImageLoading,
                   loadingView: { AnimationType.pdf.view })
        .showOfficeImportAlerts(coordinator: self.viewModel.officeImportCoordinator)
        .alertCameraPermission(isPresented: self.$viewModel.cameraPermissionDeniedShow)
        .alert("Info", isPresented: self.$viewModel.missingWidgetWarningShow, actions: {
            Button("Ok", role: .cancel, action: {})
        }, message: {
            Text("Your pdf has no  fields that you can fill in.")
        })
        .showError(self.$viewModel.pdfSaveError)
        .saveSuccessfullAlert(show: self.$viewModel.saveSuccessfulAlertShow,
                             goToArchiveCallback: { self.viewModel.goToArchive() },
                             sharePdfCallback: { self.viewModel.share() })
        .removePasswordView(show: self.$viewModel.removePasswordAlertShow,
                            removePasswordCallback: self.viewModel.removePassword)
        .addPasswordView(show: self.$viewModel.passwordTextFieldShow,
                         addPasswordCallback: { self.viewModel.setPassword($0) })
        .showShareView(coordinator: self.viewModel.pdfShareCoordinator)
        .showUnlockView(viewModel: self.viewModel.pdfUnlockViewModel)
        .showSplitView(viewModel: self.viewModel.pdfSplitViewModel)
        .splitSuccessfulAlert(show: self.$viewModel.splitSuccessAlertShow,
                              goToArchiveCallback: { self.viewModel.goToArchive() })
        .showExtractView(viewModel: self.viewModel.pdfExtractViewModel)
        .extractSuccessfulAlert(show: self.$viewModel.extractSuccessAlertShow,
                                goToArchiveCallback: { self.viewModel.goToArchive() })
        .showExportView(viewModel: self.viewModel.pdfExportViewModel)
        .showPermissionsView(viewModel: self.viewModel.pdfPermissionsViewModel)
        .showRedactView(viewModel: self.viewModel.pdfRedactViewModel)
        .showSubscriptionView(self.$viewModel.ocrMonetizationShow,
                              onComplete: { self.viewModel.onOcrMonetizationClose() })
        .showSubscriptionView(self.$viewModel.pageNumbersMonetizationShow,
                              onComplete: { self.viewModel.onPageNumbersMonetizationClose() })
        .showSubscriptionView(self.$viewModel.watermarkMonetizationShow,
                              onComplete: { self.viewModel.onWatermarkMonetizationClose() })
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

    // MARK: - Pages

    @ViewBuilder var pdfView: some View {
        if self.viewModel.pageImages.count > 0 {
            TabView(selection: self.$viewModel.pdfCurrentPageIndex) {
                ForEach(Array(self.viewModel.pageImages.enumerated()), id:\.offset) { (pageIndex, pageImage) in
                    Image(uiImage: pageImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: DS.Radius.thumbnail, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
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
        Text("\(self.viewModel.pdfCurrentPageIndex + 1) of \(self.viewModel.pageImages.count)")
            .font(forCategory: .caption1)
            .foregroundStyle(ColorPalette.textPrimary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 6)
            .floatingGlassCapsule(interactive: false)
            .padding(.top, DS.Spacing.xs)
            .animation(DS.Motion.quick, value: self.viewModel.pdfCurrentPageIndex)
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
                    ForEach(Array(self.viewModel.pdfThumbnails.enumerated()), id: \.offset) { index, image in
                        Button(action: {
                            withAnimation(DS.Motion.quick) {
                                self.viewModel.pdfCurrentPageIndex = index
                            }
                        }) {
                            VStack(spacing: 4) {
                                self.getThumbnailCell(image: image)
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
                ForEach(Array(self.viewModel.pdfThumbnails.enumerated()), id: \.offset) { index, image in
                    Button(action: {
                        withAnimation(DS.Motion.quick) {
                            self.viewModel.pdfCurrentPageIndex = index
                        }
                    }) {
                        VStack(spacing: 4) {
                            self.getThumbnailCell(image: image)
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

    // MARK: - Actions

    /// The four edits people reach for constantly. A glass bar over the page on
    /// a phone, toolbar buttons on a wide window — same four either way.
    enum PrimaryEdit: Int, CaseIterable, Identifiable {

        case page
        case signature
        case text
        case form

        var id: Int { self.rawValue }

        var title: String {
            switch self {
            case .page: return String(localized: "Page")
            case .signature: return String(localized: "Signature")
            case .text: return String(localized: "Add text")
            case .form: return String(localized: "Fill Form")
            }
        }

        var systemImage: String {
            switch self {
            case .page: return "plus.rectangle.on.rectangle"
            case .signature: return "signature"
            case .text: return "textformat"
            case .form: return "list.bullet.rectangle.portrait"
            }
        }
    }

    private func perform(_ edit: PrimaryEdit) {
        switch edit {
        case .page: self.showingImageInputPicker = true
        case .signature: self.viewModel.showAddSignature()
        case .text: self.viewModel.showFillForm()
        case .form: self.viewModel.showFillWidget()
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

    private var actionBar: some View {
        GlassEffectContainer(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(PrimaryEdit.allCases) { edit in
                    self.actionButton(title: edit.title, systemImage: edit.systemImage) {
                        self.perform(edit)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xs)
    }

    private func goToPage(_ index: Int) {
        guard index >= 0, index < self.viewModel.pageImages.count else { return }
        withAnimation(DS.Motion.quick) { self.viewModel.pdfCurrentPageIndex = index }
    }

    private func actionButton(title: String,
                              systemImage: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(forCategory: .caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(ColorPalette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .floatingGlass(radius: DS.Radius.control, interactive: true)
        .accessibilityLabel(Text(title))
    }

    /// Everything beyond the four primary edits, grouped so the list reads as
    /// four short menus instead of one long one.
    private var moreMenu: some View {
        Menu {
            // Page turning lives here so it carries a keyboard shortcut that is
            // also discoverable: nothing else in the editor is a button a
            // shortcut could sensibly hang off.
            if self.viewModel.pageImages.count > 1 {
                Section {
                    Button {
                        self.goToPage(self.viewModel.pdfCurrentPageIndex - 1)
                    } label: {
                        Label("Previous page", systemImage: "chevron.up")
                    }
                    .keyboardShortcut(.upArrow, modifiers: [.command])
                    .disabled(self.viewModel.pdfCurrentPageIndex == 0)
                    Button {
                        self.goToPage(self.viewModel.pdfCurrentPageIndex + 1)
                    } label: {
                        Label("Next page", systemImage: "chevron.down")
                    }
                    .keyboardShortcut(.downArrow, modifiers: [.command])
                    .disabled(self.viewModel.pdfCurrentPageIndex >= self.viewModel.pageImages.count - 1)
                }
            }

            if self.viewModel.pageImages.count > 0 {
                Section {
                    Button {
                        self.viewModel.rotateCurrentPage(clockwise: true)
                    } label: {
                        Label("Rotate page right", systemImage: "rotate.right")
                    }
                    Button {
                        self.viewModel.rotateCurrentPage(clockwise: false)
                    } label: {
                        Label("Rotate page left", systemImage: "rotate.left")
                    }
                    Button {
                        self.viewModel.rotateAllPages(clockwise: true)
                    } label: {
                        Label("Rotate all pages", systemImage: "arrow.trianglehead.2.clockwise")
                    }
                    Button(role: .destructive) {
                        self.showingDeleteConfermation = true
                    } label: {
                        Label("Delete this page", systemImage: "trash")
                    }
                }
            }

            Section(String(localized: "Organize pages")) {
                self.menuButton(for: .split, title: String(localized: "Split"), systemImage: "scissors")
                self.menuButton(for: .extract, title: String(localized: "Extract"), systemImage: "doc.on.doc")
                self.menuButton(for: .removeBlankPages,
                                title: String(localized: "Remove blank pages"),
                                systemImage: "rectangle.dashed")
            }

            Section(String(localized: "Edit content")) {
                self.menuButton(for: .ocr,
                                title: String(localized: "Make Searchable (OCR)"),
                                systemImage: "text.viewfinder")
                self.menuButton(for: .pageNumbers,
                                title: String(localized: "Page numbers"),
                                systemImage: "textformat.123")
                self.menuButton(for: .watermark,
                                title: String(localized: "Watermark"),
                                systemImage: "drop.halffull")
                self.menuButton(for: .invertColors,
                                title: String(localized: "Invert colors"),
                                systemImage: "circle.lefthalf.filled")
            }

            Section(String(localized: "Protect")) {
                self.menuButton(for: .password,
                                title: self.viewModel.pdf.password != nil
                                    ? String(localized: "Unlock")
                                    : String(localized: "Protect"),
                                systemImage: self.viewModel.pdf.password != nil ? "lock.open" : "lock")
                self.menuButton(for: .permissions,
                                title: String(localized: "PDF permissions"),
                                systemImage: "hand.raised")
                self.menuButton(for: .redact,
                                title: String(localized: "Redact PDF"),
                                systemImage: "eye.slash")
                self.menuButton(for: .flatten,
                                title: String(localized: "Flatten PDF"),
                                systemImage: "square.stack.3d.down.forward")
            }

            Section {
                self.menuButton(for: .compression,
                                title: String(localized: "Compress"),
                                systemImage: "arrow.down.right.and.arrow.up.left")
                self.menuButton(for: .export,
                                title: String(localized: "Export as…"),
                                systemImage: "square.and.arrow.up.on.square")
                self.menuButton(for: .metadata,
                                title: String(localized: "Document info"),
                                systemImage: "info.circle")
                Button {
                    self.viewModel.share()
                } label: {
                    Label("Share pdf", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    private func menuButton(for action: EditAction,
                            title: String,
                            systemImage: String) -> some View {
        Button {
            self.viewModel.handleEditAction(action)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    func getThumbnailCell(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .onDrag {
                self.draggedImage = image
                return NSItemProvider()
            }
            .onDrop(of: [.image],
                    delegate: PdfEditDropViewDelegate(destinationItem: image,
                                                      draggedItem: self.$draggedImage,
                                                      viewModel: self.viewModel))
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

    @ViewBuilder func saveSuccessfullAlert(show: Binding<Bool>,
                                          goToArchiveCallback: @escaping () -> (),
                                          sharePdfCallback: @escaping () -> ()) -> some View {
        self.alert("PDF saved!", isPresented: show, actions: {
            Button("Go to files", action: goToArchiveCallback)
            Button("Share pdf", action: sharePdfCallback)
            Button("Continue edit", action: {})
        }, message: {
            Text("Your pdf has been successfully saved")
        })
    }

    func splitSuccessfulAlert(show: Binding<Bool>,
                              goToArchiveCallback: @escaping () -> ()) -> some View {
        self.alert("PDF split!", isPresented: show, actions: {
            Button("Go to files", action: goToArchiveCallback)
            Button("Continue edit", action: {})
        }, message: {
            Text("Your pdf has been successfully split and saved!")
        })
    }

    func extractSuccessfulAlert(show: Binding<Bool>,
                                goToArchiveCallback: @escaping () -> ()) -> some View {
        self.alert("Pages extracted!", isPresented: show, actions: {
            Button("Go to files", action: goToArchiveCallback)
            Button("Continue edit", action: {})
        }, message: {
            Text("Your pages have been successfully extracted and saved!")
        })
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

    let destinationItem: UIImage
    @Binding var draggedItem: UIImage?
    var viewModel: PdfEditViewModel

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        // Swap Items
        if let draggedItem {
            let fromIndex = self.viewModel.pdfThumbnails.firstIndex(of: draggedItem)
            if let fromIndex {
                let toIndex = self.viewModel.pdfThumbnails.firstIndex(of: self.destinationItem)
                if let toIndex, fromIndex != toIndex {
                    self.viewModel.handlePageReordering(fromIndex: fromIndex, toIndex: toIndex)
                }
            }
        }
    }
}
