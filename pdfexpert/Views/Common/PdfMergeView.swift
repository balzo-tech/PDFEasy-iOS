//
//  PdfMergeView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 02/08/23.
//

import SwiftUI
import Factory

struct PdfMergeView: ViewModifier {
    
    @ObservedObject var viewModel: PdfMergeViewModel

    func body(content: Content) -> some View {
        content
            .showImportMultipleView(viewModel: self.viewModel.pdfImportMultipleViewModel)
            .loadingView(show: self.$viewModel.loading)
            .asyncView(asyncOperation: self.$viewModel.asyncImportedPdfs)
            .showSortView(isPresented: self.$viewModel.showPdfSorter,
                          onDismiss: { self.viewModel.onSortedCompleted() },
                          params: PdfSortViewModel.Params(
                            pdfs: self.$viewModel.toBeSortedPdfs,
                            confirmButtonText: "Merge PDF",
                            confirmCallback: {
                                self.viewModel.onSortedConfirmed()
                            },
                            cancelCallback: {
                                self.viewModel.onSortedCancelled()
                            }))
    }
}

extension View {
    func showMergeView(viewModel: PdfMergeViewModel) -> some View {
        modifier(PdfMergeView(viewModel: viewModel))
    }
}

struct PdfMergeView_Previews: PreviewProvider {
    
    static let asyncPdf: AsyncOperation<Pdf, PdfError> = .init(status: .empty)
    static let viewModel = Container.shared
        .pdfMergeViewModel(.init(asyncPdf: .constant(Self.asyncPdf)))
    
    static var previews: some View {
        Color(.white)
            .showMergeView(viewModel: Self.viewModel)
    }
}
