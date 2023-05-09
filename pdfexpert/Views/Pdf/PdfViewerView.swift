//
//  PdfViewerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 11/04/23.
//

import SwiftUI
import Factory

struct PdfViewerView: View {
    
    @StateObject var viewModel: PdfViewerViewModel
    @State var passwordTextFieldShow: Bool = false
    @State var removePasswordAlertShow: Bool = false
    @State private var passwordText: String = ""
    
    var body: some View {
        PdfKitView(
            pdfDocument: self.viewModel.pdf.pdfDocument,
            singlePage: false,
            pageMargins: UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0),
            currentPage: nil,
            backgroundColor: UIColor(ColorPalette.primaryBG)
        )
        .padding([.leading, .trailing], 16)
        .background(ColorPalette.primaryBG)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                self.passwordButton
                self.shareButton
            }
        }
        .fullScreenCover(isPresented: self.$viewModel.monetizationShow) {
            self.getSubscriptionView(onComplete: {
                self.viewModel.monetizationShow = false
            })
        }
        .sheet(item: self.$viewModel.pdfToBeShared) { pdf in
            ActivityViewController(activityItems: [pdf.shareData!],
                                   thumbnail: pdf.thumbnail)
        }
        .alert("Error",
               isPresented: .constant(self.viewModel.pdfSaveError != nil),
               presenting: self.viewModel.pdfSaveError,
               actions: { pdfSaveError in
            Button("Cancel") { self.viewModel.pdfSaveError = nil }
        }, message: { pdfSaveError in
            Text(pdfSaveError.errorDescription ?? "")
        })
    }
    
    @ViewBuilder var passwordButton: some View {
        Group {
            if self.viewModel.pdf.password != nil {
                Button(action: { self.removePasswordAlertShow = true }) {
                    Image("password_entered")
                        .foregroundColor(ColorPalette.primaryText)
                }
            } else {
                Button(action: { self.passwordTextFieldShow = true }) {
                    Image("password_missing")
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
        }
        .alert("Would you like to remove your password?", isPresented: self.$removePasswordAlertShow, actions: {
            Button("Delete", role: .destructive, action: { self.viewModel.removePassword() })
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("If you decide to remove the password, your PDF will no longer be protected.")
        })
        .alert("Protect PDF using password", isPresented: self.$passwordTextFieldShow, actions: {
            SecureField("Enter Password", text: self.$passwordText)
            Button("Confirm", action: {
                self.viewModel.setPassword(self.passwordText)
                self.passwordText = ""
            })
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("Enter a password to protect your PDF file.")
        })
    }
    
    var shareButton: some View {
        Button(action: { self.viewModel.share() }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(ColorPalette.primaryText)
                .font(.system(size: 16).bold())
        }
    }
}

struct PdfViewerView_Previews: PreviewProvider {
    
    static let inputParameter: PdfViewerViewModel.InputParameter? = {
        if let pdf = K.Test.DebugPdf {
            let marginOption = K.Misc.PdfDefaultMarginOption
            let quality = K.Misc.PdfDefaultQuality
            return PdfViewerViewModel.InputParameter(pdf: pdf,
                                                     marginsOption: marginOption,
                                                     quality: quality)
        } else {
            return nil
        }
    }()
    
    static var previews: some View {
        if let inputParameter = Self.inputParameter {
            AnyView(PdfViewerView(viewModel: Container.shared.pdfViewerViewModel(inputParameter)))
        } else {
            AnyView(Spacer())
        }
    }
}
