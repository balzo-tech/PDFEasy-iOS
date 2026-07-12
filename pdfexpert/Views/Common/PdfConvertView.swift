//
//  PdfConvertView.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//
//  Host modifier for the PDF → Word / PowerPoint / Excel conversions. Clones
//  PdfExportView: import view + async loader + share sheet + paywall, with the
//  added one-time privacy disclosure alert (the document is uploaded to the
//  conversion service). The output format is preselected by the Home tile, so no
//  format picker is needed here.
//

import SwiftUI
import Factory

struct PdfConvertView: ViewModifier {

    @ObservedObject var viewModel: PdfConvertViewModel

    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncOperation: self.$viewModel.asyncConvert,
                       loadingView: { self.convertingLoadingView })
            .alert(String(localized: "Online conversion"),
                   isPresented: self.$viewModel.disclosureAlertShow,
                   actions: {
                Button(String(localized: "Cancel"), role: .cancel) {
                    self.viewModel.onDisclosureCancelled()
                }
                Button(String(localized: "Continue")) {
                    self.viewModel.onDisclosureAccepted()
                }
            }, message: {
                Text("This PDF is sent securely to the conversion service and deleted after processing.")
            })
            .sheet(item: self.$viewModel.convertResultToShare,
                   onDismiss: { self.viewModel.onShareDismiss() }) { result in
                ActivityViewController(activityItems: result.urls,
                                       thumbnail: result.pdf.thumbnail,
                                       title: result.pdf.filename)
            }
            .showSubscriptionView(self.$viewModel.monetizationShow,
                                  onComplete: { self.viewModel.onMonetizationClose() })
    }

    @ViewBuilder private var convertingLoadingView: some View {
        ZStack {
            AnimationType.pdf.view
            VStack {
                Spacer()
                Text("Converting…")
                    .font(forCategory: .headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 80)
            }
        }
    }
}

extension View {
    func showConvertView(viewModel: PdfConvertViewModel) -> some View {
        modifier(PdfConvertView(viewModel: viewModel))
    }
}

struct PdfConvertView_Previews: PreviewProvider {

    static let viewModel = Container.shared.pdfConvertViewModel()

    static var previews: some View {
        Color(.white)
            .showConvertView(viewModel: Self.viewModel)
    }
}
