//
//  UnlockView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/07/23.
//

import SwiftUI

typealias UnlockCallback = (String) -> ()

struct UnlockView: ViewModifier {
    
    @Binding var show: Bool
    
    @State var passwordText: String = ""
    
    let unlockCallback: UnlockCallback
    
    func body(content: Content) -> some View {
        content
            .alert("Your pdf is protected", isPresented: self.$show, actions: {
                SecureField("Enter Password", text: self.$passwordText)
                Button("Confirm", action: {
                    self.unlockCallback(self.passwordText)
                    self.passwordText = ""
                })
                Button("Cancel", role: .cancel, action: {})
            }, message: {
                Text("Enter the password of your pdf in order to import it.")
            })
    }
}

extension View {
    func unlockView(show: Binding<Bool>,
                    unlockCallback: @escaping UnlockCallback) -> some View {
        modifier(UnlockView(show: show, unlockCallback: unlockCallback))
    }
}

struct UnlockView_Previews: PreviewProvider {
    static var previews: some View {
        Color(.white)
            .unlockView(show: .constant(true),
                        unlockCallback: { print("Unlock completed: \($0)") })
    }
}
