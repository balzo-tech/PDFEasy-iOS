//
//  PdfWebImportView.swift
//  PdfExpert
//
//  Address prompt for "Web page to PDF". An alert with a single field is enough here
//  (same shape as the password prompt); the loading state and any error come from the
//  host's async channel, which the view model drives.
//

import SwiftUI

struct PdfWebImportView: ViewModifier {

    @ObservedObject var viewModel: PdfWebImportViewModel

    @State private var urlText: String = ""

    func body(content: Content) -> some View {
        content
            .alert(String(localized: "Web page to PDF"),
                   isPresented: self.$viewModel.urlInputShow,
                   actions: {
                TextField(String(localized: "example.com"), text: self.$urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(String(localized: "Convert")) {
                    let text = self.urlText
                    self.urlText = ""
                    self.viewModel.convert(urlText: text)
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    self.urlText = ""
                }
            }, message: {
                Text("Enter the address of the page you want to save as a PDF.")
            })
    }
}

extension View {
    func showWebImportView(viewModel: PdfWebImportViewModel) -> some View {
        self.modifier(PdfWebImportView(viewModel: viewModel))
    }
}
