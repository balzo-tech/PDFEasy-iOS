//
//  PdfUnlockView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 02/08/23.
//

import SwiftUI
import Factory

struct PdfUnlockView: ViewModifier {
    
    @ObservedObject var viewModel: PdfUnlockViewModel
    
    func body(content: Content) -> some View {
        content
            .alert("Your pdf is protected",
                   isPresented: self.$viewModel.showPasswordInputView,
                   actions: {
                SecureField("Enter Password", text: self.$viewModel.passwordText)
                Button("Confirm", action: {
                    self.viewModel.decryptPdf()
                })
                Button("Cancel", role: .cancel, action: {})
            }, message: {
                Text("Enter the password of\n\(self.viewModel.unlockingPdf?.filename ?? "")\nin order to import it.")
            })
            .asyncView(asyncOperation: self.$viewModel.asyncUnlockedPdf)
    }
}

extension View {
    func showUnlockView(viewModel: PdfUnlockViewModel) -> some View {
        modifier(PdfUnlockView(viewModel: viewModel))
    }
}

struct PdfUnlockView_Previews: PreviewProvider {
    
    static let asyncUnlockedPdfSingle: AsyncOperation<Pdf, PdfError> = .init(status: .empty)
    static let viewModel = Container.shared
        .pdfUnlockViewModel(.init(asyncUnlockedPdfSingleOutput: .constant(Self.asyncUnlockedPdfSingle)))
    
    static var previews: some View {
        Color(.white)
            .showUnlockView(viewModel: Self.viewModel)
    }
}
