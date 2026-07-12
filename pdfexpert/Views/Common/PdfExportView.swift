//
//  PdfExportView.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//

import SwiftUI
import Factory

struct PdfExportView: ViewModifier {

    @ObservedObject var viewModel: PdfExportViewModel

    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncOperation: self.$viewModel.asyncExport,
                       loadingView: { AnimationType.pdf.view })
            // Height derived from the option count, matching the edit-options sheet.
            .formSheet(isPresented: self.$viewModel.formatPickerShow,
                       size: CGSize(width: 400.0, height: 96.0 + 58.0 * CGFloat(PdfExportFormat.allCases.count))) {
                self.formatPickerView
            }
            .sheet(item: self.$viewModel.exportResultToShare,
                   onDismiss: { self.viewModel.onShareDismiss() }) { result in
                ActivityViewController(activityItems: result.urls,
                                       thumbnail: result.pdf.thumbnail,
                                       title: result.pdf.filename)
            }
            .showSubscriptionView(self.$viewModel.monetizationShow,
                                  onComplete: { self.viewModel.onMonetizationClose() })
    }

    @ViewBuilder private var formatPickerView: some View {
        OptionListView(title: String(localized: "Export PDF as…"),
                       items: [
            OptionItem(title: String(localized: "Images (PNG)"),
                       imageName: "photo",
                       isSystemImage: true,
                       callBack: { self.viewModel.onFormatSelected(.imagesPng) }),
            OptionItem(title: String(localized: "Images (JPEG)"),
                       imageName: "photo.fill",
                       isSystemImage: true,
                       callBack: { self.viewModel.onFormatSelected(.imagesJpeg) }),
            OptionItem(title: String(localized: "Text file"),
                       imageName: "doc.plaintext",
                       isSystemImage: true,
                       callBack: { self.viewModel.onFormatSelected(.text) }),
            OptionItem(title: String(localized: "Embedded images"),
                       imageName: "photo.on.rectangle",
                       isSystemImage: true,
                       callBack: { self.viewModel.onFormatSelected(.embeddedImages) }),
        ])
    }
}

extension View {
    func showExportView(viewModel: PdfExportViewModel) -> some View {
        modifier(PdfExportView(viewModel: viewModel))
    }
}

struct PdfExportView_Previews: PreviewProvider {

    static let viewModel = Container.shared.pdfExportViewModel()

    static var previews: some View {
        Color(.white)
            .showExportView(viewModel: Self.viewModel)
    }
}
