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

enum EditorRoute: Hashable {
    case reorderPages
    case pageNumbers
    case watermark
    case metadata
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
                let parameter = PdfWatermarkViewModel
                    .InputParameter(pdf: self.viewModel.pdf,
                                    onConfirm: { self.viewModel.updatePdf(pdf: $0) })
                PdfWatermarkView(viewModel: Container.shared.pdfWatermarkViewModel(parameter))
            case .metadata:
                let parameter = PdfMetadataViewModel
                    .InputParameter(pdf: self.viewModel.pdf,
                                    onConfirm: { self.viewModel.applyMetadata(pdf: $0) })
                PdfMetadataView(viewModel: Container.shared.pdfMetadataViewModel(parameter))
            }
        }
        .environment(\.isPushedToolScreen, true)
    }
}
