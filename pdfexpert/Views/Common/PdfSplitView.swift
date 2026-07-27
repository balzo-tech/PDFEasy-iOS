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
            .splitOutcomes(viewModel: self.viewModel)
            .showPageRangeEditorView(isPresented: self.$viewModel.showPageRangeEditor,
                                     onDismiss: { self.viewModel.onPageRangeEditingCompleted() },
                                     title: String(localized: "Split pages into ranges"),
                                     confirmTitle: String(localized: "Split PDF"),
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

/// What the flow says back: the loader over the work and any error it hits.
/// Separate from the modifier above because the editor pushes the range editor
/// itself, and would otherwise present it twice — but it still wants the loader
/// and the errors, over the document.
struct PdfSplitOutcomes: ViewModifier {

    @ObservedObject var viewModel: PdfSplitViewModel

    func body(content: Content) -> some View {
        content
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncItem: self.$viewModel.asyncSplit)
    }
}

extension View {

    func showSplitView(viewModel: PdfSplitViewModel) -> some View {
        modifier(PdfSplitView(viewModel: viewModel))
    }

    func splitOutcomes(viewModel: PdfSplitViewModel) -> some View {
        modifier(PdfSplitOutcomes(viewModel: viewModel))
    }
}

struct PdfSplitView_Previews: PreviewProvider {
    
    static let viewModel = Container.shared.pdfSplitViewModel()
    
    static var previews: some View {
        Color(.white)
            .showSplitView(viewModel: Self.viewModel)
    }
}
