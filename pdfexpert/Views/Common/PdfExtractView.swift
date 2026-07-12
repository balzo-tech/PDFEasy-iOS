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
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncItem: self.$viewModel.asyncExtract)
            .showPageRangeEditorView(isPresented: self.$viewModel.showPageRangeEditor,
                                     onDismiss: { self.viewModel.onPageRangeEditingCompleted() },
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

extension View {
    func showExtractView(viewModel: PdfExtractViewModel) -> some View {
        modifier(PdfExtractView(viewModel: viewModel))
    }
}

struct PdfExtractView_Previews: PreviewProvider {

    static let viewModel = Container.shared.pdfExtractViewModel()

    static var previews: some View {
        Color(.white)
            .showExtractView(viewModel: Self.viewModel)
    }
}
