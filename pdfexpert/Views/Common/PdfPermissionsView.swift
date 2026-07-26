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
            .asyncView(asyncItem: self.$viewModel.asyncImportedPdf)
            .fullScreenCover(isPresented: self.$viewModel.formShow) {
                self.formView
            }
            .asyncView(asyncItem: self.$viewModel.asyncApply)
            .alert(String(localized: "Done"), isPresented: self.$viewModel.successAlertShow, actions: {
                Button("Ok", role: .cancel, action: {})
            }, message: {
                Text("A protected copy has been saved to your archive.")
            })
            .showSubscriptionView(self.$viewModel.monetizationShow,
                                  onComplete: { self.viewModel.onMonetizationClose() })
    }

    private var formView: some View {
        NavigationStack {
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(String(localized: "PDF permissions"))
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.viewModel.cancel()
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Confirm")) {
                        self.viewModel.confirm()
                    }
                    .disabled(!self.viewModel.canConfirm)
                    .foregroundColor(self.viewModel.canConfirm ? ColorPalette.primaryText : ColorPalette.thirdText)
                }
            }
        }
    }
}

extension View {
    func showPermissionsView(viewModel: PdfPermissionsViewModel) -> some View {
        self.modifier(PdfPermissionsView(viewModel: viewModel))
    }
}
