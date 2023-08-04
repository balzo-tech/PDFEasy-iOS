//
//  PdfImportView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import SwiftUI
import Factory

struct PdfImportView: ViewModifier {
    
    @ObservedObject var viewModel: PdfImportViewModel

    func body(content: Content) -> some View {
        content
            .filePicker(isPresented: self.$viewModel.showFilePicker,
                        fileTypes: self.viewModel.importFileTypes,
                        multipleSelection: false,
                        onPickedFiles: {
                self.viewModel.processSelectedUrls($0)
            })
            .showUnlockView(viewModel: self.viewModel.pdfUnlockViewModel)
            .loadingView(show: self.$viewModel.loading)
    }
}

extension View {
    func showImportView(viewModel: PdfImportViewModel) -> some View {
        modifier(PdfImportView(viewModel: viewModel))
    }
}

struct PdfImportView_Previews: PreviewProvider {
    
    static let asyncPdf: AsyncOperation<Pdf, PdfError> = .init(status: .empty)
    static let viewModel = Container.shared
        .pdfImportViewModel(.init(asyncPdf: .constant(Self.asyncPdf)))
    
    static var previews: some View {
        Color(.white)
            .showImportView(viewModel: Self.viewModel)
    }
}
