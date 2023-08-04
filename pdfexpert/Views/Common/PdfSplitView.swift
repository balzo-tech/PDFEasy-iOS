//
//  PdfSplitView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import SwiftUI
import Factory

struct PdfSplitView: ViewModifier {
    
    @ObservedObject var viewModel: PdfSplitViewModel
    
    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncItem: self.$viewModel.asyncSplit)
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
    func showSplitView(viewModel: PdfSplitViewModel) -> some View {
        modifier(PdfSplitView(viewModel: viewModel))
    }
}

struct PdfSplitView_Previews: PreviewProvider {
    
    static let viewModel = Container.shared.pdfSplitViewModel()
    
    static var previews: some View {
        Color(.white)
            .showSplitView(viewModel: Self.viewModel)
    }
}
