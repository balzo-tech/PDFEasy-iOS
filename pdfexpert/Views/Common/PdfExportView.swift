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
            .exportOutcomes(viewModel: self.viewModel)
            // Height derived from the option count, matching the edit-options sheet.
            .formSheet(isPresented: self.$viewModel.formatPickerShow,
                       size: CGSize(width: 400.0, height: 96.0 + 58.0 * CGFloat(PdfExportFormat.allCases.count))) {
                self.formatPickerView
            }
    }

    @ViewBuilder private var formatPickerView: some View {
        OptionListView(title: String(localized: "Export PDF as…"),
                       items: PdfExportFormat.allCases.map { format in
            OptionItem(title: format.title,
                       imageName: format.systemImage,
                       isSystemImage: true,
                       callBack: { self.viewModel.onFormatSelected(format) })
        })
    }
}

/// Everything after the format is chosen: the loader, the share sheet the files
/// leave through, and the paywall. Unlike the other four flows the premium gate
/// belongs here rather than to the host — export gates on the *format*, which
/// only exists once the form has been answered.
struct PdfExportOutcomes: ViewModifier {

    @ObservedObject var viewModel: PdfExportViewModel

    func body(content: Content) -> some View {
        content
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncOperation: self.$viewModel.asyncExport,
                       loadingView: { AnimationType.pdf.view })
            .sheet(item: self.$viewModel.exportResultToShare,
                   onDismiss: { self.viewModel.onShareDismiss() }) { result in
                ActivityViewController(activityItems: result.urls,
                                       thumbnail: result.pdf.thumbnail,
                                       title: result.pdf.filename)
            }
            .showSubscriptionView(self.$viewModel.monetizationShow,
                                  onComplete: { self.viewModel.onMonetizationClose() })
    }
}

extension View {

    func showExportView(viewModel: PdfExportViewModel) -> some View {
        modifier(PdfExportView(viewModel: viewModel))
    }

    func exportOutcomes(viewModel: PdfExportViewModel) -> some View {
        modifier(PdfExportOutcomes(viewModel: viewModel))
    }
}

struct PdfExportView_Previews: PreviewProvider {

    static let viewModel = Container.shared.pdfExportViewModel()

    static var previews: some View {
        Color(.white)
            .showExportView(viewModel: Self.viewModel)
    }
}
