//
//  PdfExtractView.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//

import SwiftUI
import Factory

struct PdfExtractView: ViewModifier {

    @ObservedObject var viewModel: PdfExtractViewModel

    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .extractOutcomes(viewModel: self.viewModel)
            .showPageRangeEditorView(isPresented: self.$viewModel.showPageRangeEditor,
                                     onDismiss: { self.viewModel.onPageRangeEditingCompleted() },
                                     title: String(localized: "Extract pages"),
                                     confirmTitle: String(localized: "Extract pages"),
                                     params: PdfPageRangeEditorViewModel.Params(
                                        pageRanges: self.$viewModel.pageRanges,
                                        totalPages: self.viewModel.totalPages,
                                        confirmCallback: {
                                            self.viewModel.onPageRangeEditingConfirmed()
                                        },
                                        cancelCallback: {
                                            self.viewModel.onPageRangeEditingCancelled()
                                        }))
    }
}

/// The loader and the errors, without the range editor — see `PdfSplitOutcomes`.
struct PdfExtractOutcomes: ViewModifier {

    @ObservedObject var viewModel: PdfExtractViewModel

    func body(content: Content) -> some View {
        content
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncItem: self.$viewModel.asyncExtract)
    }
}

extension View {

    func showExtractView(viewModel: PdfExtractViewModel) -> some View {
        modifier(PdfExtractView(viewModel: viewModel))
    }

    func extractOutcomes(viewModel: PdfExtractViewModel) -> some View {
        modifier(PdfExtractOutcomes(viewModel: viewModel))
    }
}

struct PdfExtractView_Previews: PreviewProvider {

    static let viewModel = Container.shared.pdfExtractViewModel()

    static var previews: some View {
        Color(.white)
            .showExtractView(viewModel: Self.viewModel)
    }
}
