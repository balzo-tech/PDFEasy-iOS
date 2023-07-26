//
//  AddPasswordView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 26/07/23.
//

import SwiftUI

typealias AddPasswordCallback = (String) -> ()

struct AddPasswordView: ViewModifier {
    
    @Binding var show: Bool
    
    @State var passwordText: String = ""
    
    let addPasswordCallback: AddPasswordCallback

    func body(content: Content) -> some View {
        content
            .alert("Protect PDF using password", isPresented: self.$show, actions: {
            SecureField("Enter Password", text: self.$passwordText)
            Button("Confirm", action: {
                self.addPasswordCallback(self.passwordText)
                self.passwordText = ""
            })
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("Enter a password to protect your PDF file.")
        })
    }
}

extension View {
    func addPasswordView(show: Binding<Bool>,
                         addPasswordCallback: @escaping AddPasswordCallback) -> some View {
        modifier(AddPasswordView(show: show, addPasswordCallback: addPasswordCallback))
    }
}

struct AddPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        Color(.white)
            .addPasswordView(show: .constant(true),
                             addPasswordCallback: { print("Add Password completed: \($0)") })
    }
}
