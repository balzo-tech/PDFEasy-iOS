//
//  PdfPermissionsView.swift
//  PdfExpert
//
//  Form for the "PDF permissions" tool: owner password plus the printing / copying
//  toggles, followed by the loader, the paywall and the success alert.
//

import SwiftUI

struct PdfPermissionsView: ViewModifier {

    @ObservedObject var viewModel: PdfPermissionsViewModel

    func body(content: Content) -> some View {
        content
            .showImportView(viewModel: self.viewModel.pdfImportViewModel)
            .permissionsOutcomes(viewModel: self.viewModel)
            .fullScreenCover(isPresented: self.$viewModel.formShow) {
                self.formView
            }
    }

    private var formView: some View {
        PdfPermissionsFormView(viewModel: self.viewModel)
    }
}

/// The loader and the "it was saved" alert. Not the form — the editor pushes that.
struct PdfPermissionsOutcomes: ViewModifier {

    @ObservedObject var viewModel: PdfPermissionsViewModel

    func body(content: Content) -> some View {
        content
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .asyncView(asyncItem: self.$viewModel.asyncApply)
            .alert(String(localized: "Done"), isPresented: self.$viewModel.successAlertShow, actions: {
                Button("Ok", role: .cancel, action: {})
            }, message: {
                Text("A protected copy has been saved to your archive.")
            })
    }
}

/// The form itself, so the editor can push it while the Tools tab keeps
/// presenting it modally.
struct PdfPermissionsFormView: View {

    @ObservedObject var viewModel: PdfPermissionsViewModel

    var body: some View {
        ToolScreen(title: String(localized: "PDF permissions"),
                   confirm: ToolScreenAction(title: String(localized: "Confirm"),
                                             isEnabled: self.viewModel.canConfirm,
                                             action: { self.viewModel.confirm() }),
                   onCancel: { self.viewModel.cancel() }) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Owner password")
                        .font(forCategory: .headline)
                        .foregroundColor(ColorPalette.primaryText)
                    SecureField(String(localized: "Enter Password"), text: self.$viewModel.ownerPassword)
                        .font(forCategory: .body2)
                        .foregroundColor(ColorPalette.primaryText)
                        .padding(12)
                        .background(ColorPalette.secondaryBG)
                        .cornerRadius(8)
                    Text("The document still opens without a password. The owner password is what makes the restrictions below enforceable.")
                        .font(forCategory: .caption1)
                        .foregroundColor(ColorPalette.thirdText)
                }

                VStack(spacing: 12) {
                    Toggle(isOn: self.$viewModel.allowsPrinting) {
                        Text("Allow printing")
                            .font(forCategory: .body2)
                            .foregroundColor(ColorPalette.primaryText)
                    }
                    Toggle(isOn: self.$viewModel.allowsCopying) {
                        Text("Allow copying text")
                            .font(forCategory: .body2)
                            .foregroundColor(ColorPalette.primaryText)
                    }
                }

                Text("Copy protection is a convention that PDF readers choose to respect: it discourages copying but does not make the text unreadable.")
                    .font(forCategory: .caption1)
                    .foregroundColor(ColorPalette.thirdText)

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readableColumn()
            .background(ColorPalette.primaryBG)
        }
    }
}

extension View {

    func showPermissionsView(viewModel: PdfPermissionsViewModel) -> some View {
        self.modifier(PdfPermissionsView(viewModel: viewModel))
    }

    func permissionsOutcomes(viewModel: PdfPermissionsViewModel) -> some View {
        self.modifier(PdfPermissionsOutcomes(viewModel: viewModel))
    }
}
