//
//  PdfReadView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import SwiftUI

struct PdfReadViewModifier: ViewModifier {
    
    @ObservedObject var viewModel: PdfReadViewModel
    
    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .showPdfReaderView(item: self.$viewModel.toBeReadPdf)
    }
}

extension View {
    func showReadView(viewModel: PdfReadViewModel) -> some View {
        self.modifier(PdfReadViewModifier(viewModel: viewModel))
    }
}
