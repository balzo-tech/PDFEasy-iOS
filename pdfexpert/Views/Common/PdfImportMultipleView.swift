//
//  PdfImportMultipleView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/08/23.
//

import SwiftUI
import Factory

struct PdfImportMultipleView: ViewModifier {
    
    @ObservedObject var viewModel: PdfImportMultipleViewModel

    func body(content: Content) -> some View {
        content
            .filePicker(isPresented: self.$viewModel.showFilePicker,
                        fileTypes: self.viewModel.importFileTypes,
                        multipleSelection: true,
                        onPickedFiles: {
                self.viewModel.processSelectedUrls($0)
            })
            .showUnlockView(viewModel: self.viewModel.pdfUnlockViewModel)
            .loadingView(show: self.$viewModel.loading)
    }
}

extension View {
    func showImportMultipleView(viewModel: PdfImportMultipleViewModel) -> some View {
        modifier(PdfImportMultipleView(viewModel: viewModel))
    }
}

struct PdfImportMultipleView_Previews: PreviewProvider {
    
    static let asyncPdfs: AsyncOperation<[Pdf], PdfError> = .init(status: .empty)
    static let viewModel = Container.shared
        .pdfImportMultipleViewModel(.init(asyncPdfs: .constant(Self.asyncPdfs)))
    
    static var previews: some View {
        Color(.white)
            .showImportMultipleView(viewModel: Self.viewModel)
    }
}
