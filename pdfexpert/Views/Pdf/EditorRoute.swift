//
//  EditorRoute.swift
//  PdfExpert
//
//  Where the editor can go, and what it shows when it gets there.
//
//  The editor was already inside a `NavigationStack` — it simply never used it,
//  presenting every tool as a modal over the page instead. A pushed screen keeps
//  the document one back-swipe away, gives the tool a title bar it does not have
//  to draw itself, and, on a wide window, leaves the page beside it.
//

import SwiftUI
import Factory

/// `CaseIterable` so the tests can walk every destination and check something
/// opens it: a route nothing reaches is a screen nobody can get to.
enum EditorRoute: Hashable, CaseIterable {
    case reorderPages
    case pageNumbers
    case watermark
    case metadata
    // The five that were flows: their view models still run the flow, the editor
    // just shows the form. See `EditorToolScreens.swift`.
    case split
    case extractPages
    case export
    case compress
    case permissions
}

/// The one place that turns a route into a screen. Everything it builds is
/// marked as pushed, so `ToolScreen` drops the modal chrome the same tools use
/// when the Tools tab opens them.
struct EditorDestinationView: View {

    let route: EditorRoute
    @ObservedObject var viewModel: PdfEditViewModel

    var body: some View {
        Group {
            switch self.route {
            case .reorderPages:
                PdfPageReorderView(viewModel: self.viewModel)
            case .pageNumbers:
                let parameter = PdfPageNumberViewModel
                    .InputParameter(pdf: self.viewModel.pdf,
                                    onConfirm: { self.viewModel.updatePdf(pdf: $0) })
                PdfPageNumberView(viewModel: Container.shared.pdfPageNumberViewModel(parameter))
            case .watermark:
                // No `updatePdf`: the watermark is filed as its own document and the
                // one open here stays clean. The editor only says where the copy went.
                let parameter = PdfWatermarkViewModel
                    .InputParameter(pdf: self.viewModel.pdf,
                                    onSaved: { self.viewModel.onWatermarkSaved() })
                PdfWatermarkView(viewModel: Container.shared.pdfWatermarkViewModel(parameter))
            case .metadata:
                let parameter = PdfMetadataViewModel
                    .InputParameter(pdf: self.viewModel.pdf,
                                    onConfirm: { self.viewModel.applyMetadata(pdf: $0) })
                PdfMetadataView(viewModel: Container.shared.pdfMetadataViewModel(parameter))
            case .split:
                EditorPageRangeScreen(flow: self.viewModel.pdfSplitViewModel,
                                      title: String(localized: "Split pages into ranges"),
                                      confirmTitle: String(localized: "Split PDF"))
            case .extractPages:
                EditorPageRangeScreen(flow: self.viewModel.pdfExtractViewModel,
                                      title: String(localized: "Extract pages"),
                                      confirmTitle: String(localized: "Extract pages"))
            case .export:
                EditorExportScreen(viewModel: self.viewModel.pdfExportViewModel)
            case .compress:
                EditorCompressScreen(viewModel: self.viewModel.pdfCompressViewModel)
            case .permissions:
                EditorPermissionsScreen(viewModel: self.viewModel.pdfPermissionsViewModel)
            }
        }
        .environment(\.isPushedToolScreen, true)
    }
}
