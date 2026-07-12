//
//  PdfAdvancedToolView.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//
//  Host modifier for the PDF-in / PDF-out Stirling tools (Convert to PDF/A, Repair,
//  Sanitize). Clones PdfConvertView: import view + async loader + one-time privacy
//  disclosure alert (the document is uploaded to the processing service). Unlike the
//  Office conversions there is no share sheet — the processed PDF is saved to the
//  archive and a success alert confirms it. The tool is preselected by the Home tile.
//

import SwiftUI
import Factory

struct PdfAdvancedToolView: ViewModifier {

    @ObservedObject var viewModel: PdfAdvancedToolViewModel

    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncItem: self.$viewModel.asyncRun,
                       loadingView: { self.processingLoadingView })
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
            .alert(String(localized: "PDF saved"),
                   isPresented: self.$viewModel.successAlertShow,
                   actions: {
                Button(String(localized: "OK"), role: .cancel) { }
            }, message: {
                Text(self.viewModel.successMessage)
            })
            .showSubscriptionView(self.$viewModel.monetizationShow,
                                  onComplete: { self.viewModel.onMonetizationClose() })
    }

    @ViewBuilder private var processingLoadingView: some View {
        ZStack {
            AnimationType.pdf.view
            VStack {
                Spacer()
                Text("Processing…")
                    .font(forCategory: .headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 80)
            }
        }
    }
}

extension View {
    func showAdvancedToolView(viewModel: PdfAdvancedToolViewModel) -> some View {
        modifier(PdfAdvancedToolView(viewModel: viewModel))
    }
}

struct PdfAdvancedToolView_Previews: PreviewProvider {

    static let viewModel = Container.shared.pdfAdvancedToolViewModel()

    static var previews: some View {
        Color(.white)
            .showAdvancedToolView(viewModel: Self.viewModel)
    }
}
