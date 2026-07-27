//
//  EditorToolScreens.swift
//  PdfExpert
//
//  The five tools the editor used to cover itself with, as screens on its stack.
//
//  Each of them is longer than a question — an import, a form, a second document
//  saved to the archive, an alert — and its view model owns that sequence. Only
//  the middle of it moved. The flow prepares itself and raises its own "the form
//  is up" flag; the Tools tab binds that flag to a cover, the editor pushes the
//  screen and lets `popWhenFormCloses` take it away again when the flag falls.
//  Neither the flow nor the form has to know which host it got.
//
//  What stays behind, over the document, is everything the flow says back: the
//  loader, the errors, the alert that says a copy was saved. Those are the
//  `*Outcomes` modifiers, applied in `pdfEditAlerts`.
//

import SwiftUI
import Factory

// MARK: - Coming back

extension View {

    /// Pops a pushed tool form when its flow says the form is done — the same
    /// flag that dismisses the cover when the Tools tab shows the same screen.
    ///
    /// `onClose` is the flow's own "the form went away" work, the counterpart of
    /// the cover's `onDismiss`. It runs before the pop, so whatever it starts is
    /// already under way — and its progress already visible over the document —
    /// by the time the page is back.
    func popWhenFormCloses(_ isFormUp: Bool, onClose: (() -> Void)? = nil) -> some View {
        self.modifier(PopWhenFormCloses(isFormUp: isFormUp, onClose: onClose))
    }
}

private struct PopWhenFormCloses: ViewModifier {

    let isFormUp: Bool
    let onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.onChange(of: self.isFormUp) { _, isUp in
            guard !isUp else { return }
            self.onClose?()
            self.dismiss()
        }
    }
}

// MARK: - Page ranges (split and extract)

/// What split and extract have in common: a document waiting on a set of page
/// ranges. They are the same screen, so they are the same screen here too.
@MainActor
protocol PageRangeFlow: ObservableObject {

    var pageRanges: [ClosedRange<Int>] { get set }
    var totalPages: Int { get }
    var showPageRangeEditor: Bool { get }

    func onPageRangeEditingConfirmed()
    func onPageRangeEditingCancelled()
    func onPageRangeEditingCompleted()
}

extension PdfSplitViewModel: PageRangeFlow {}
extension PdfExtractViewModel: PageRangeFlow {}

struct EditorPageRangeScreen<Flow: PageRangeFlow>: View {

    @ObservedObject private var flow: Flow
    /// Built once, with the screen: the ranges being typed live in here, and a
    /// view model rebuilt on the next redraw would lose them mid-edit.
    @StateObject private var rangeViewModel: PdfPageRangeEditorViewModel

    private let title: String
    private let confirmTitle: String

    init(flow: Flow, title: String, confirmTitle: String) {
        self._flow = ObservedObject(wrappedValue: flow)
        self.title = title
        self.confirmTitle = confirmTitle
        let parameters = PdfPageRangeEditorViewModel
            .Params(pageRanges: Binding(get: { flow.pageRanges }, set: { flow.pageRanges = $0 }),
                    totalPages: flow.totalPages,
                    confirmCallback: { flow.onPageRangeEditingConfirmed() },
                    cancelCallback: { flow.onPageRangeEditingCancelled() })
        self._rangeViewModel = StateObject(wrappedValue: Container.shared.pdfPageRangeEditorViewModel(parameters))
    }

    var body: some View {
        PdfPageRangeEditorView(viewModel: self.rangeViewModel,
                               title: self.title,
                               confirmTitle: self.confirmTitle)
            // Exactly what the cover does on dismissal: the work runs, and it is
            // a no-op if the ranges were cancelled rather than confirmed.
            .popWhenFormCloses(self.flow.showPageRangeEditor,
                               onClose: { self.flow.onPageRangeEditingCompleted() })
            // Leaving by the back button is a cancellation. Safe after a confirm
            // too: by then the work holds its own copy of the document.
            .onDisappear { self.flow.onPageRangeEditingCancelled() }
    }
}

// MARK: - Export

/// The four formats, as a screen rather than the sheet the Tools tab shows. The
/// paywall is not here: export gates on the format, so it comes up once the
/// screen is gone, over the document (see `PdfExportOutcomes`).
struct EditorExportScreen: View {

    @ObservedObject var viewModel: PdfExportViewModel

    var body: some View {
        ToolScreen(title: String(localized: "Export PDF as…")) {
            ZStack {
                ColorPalette.background.ignoresSafeArea()
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(PdfExportFormat.allCases, id: \.self) { format in
                        OptionItemView(title: format.title,
                                       imageName: format.systemImage,
                                       isSystemImage: true,
                                       onPressed: { self.viewModel.onFormatSelected(format) })
                            .contentCard(radius: DS.Radius.control)
                    }
                    Spacer(minLength: 0)
                }
                .padding(DS.Spacing.md)
                .readableColumn()
            }
        }
        .popWhenFormCloses(self.viewModel.formatPickerShow)
    }
}

// MARK: - Compress

struct EditorCompressScreen: View {

    @ObservedObject var viewModel: PdfCompressViewModel

    var body: some View {
        PdfCompressEditorView(viewModel: self.viewModel)
            .popWhenFormCloses(self.viewModel.editorShow)
            // Backing out releases the compressed copy and its preview, which are
            // the size of the document. Harmless after a save: that path has
            // already taken what it needs.
            .onDisappear { self.viewModel.cancel() }
    }
}

// MARK: - Permissions

struct EditorPermissionsScreen: View {

    @ObservedObject var viewModel: PdfPermissionsViewModel

    var body: some View {
        PdfPermissionsFormView(viewModel: self.viewModel)
            .popWhenFormCloses(self.viewModel.formShow)
            // Same as above, and it clears the owner password: a field the user
            // walked away from should not still be filled in next time.
            .onDisappear { self.viewModel.cancel() }
    }
}
