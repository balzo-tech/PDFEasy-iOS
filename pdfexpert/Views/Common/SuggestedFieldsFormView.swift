//
//  SuggestedFieldsFormView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 07/09/23.
//

import SwiftUI
import Factory

struct SuggestedFieldsFormView: View {
    
    @InjectedObject(\.suggestedFieldsFormViewModel) var viewModel: SuggestedFieldsFormViewModel
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section(header: self.headerView) {}
                    self.getTextField(name: "First Name",
                                      text: self.$viewModel.firstName,
                                      textContentType: .givenName)
                    self.getTextField(name: "Last Name",
                                      text: self.$viewModel.lastName,
                                      textContentType: .familyName)
                }
                VStack {
                    Spacer()
                    self.getDefaultButton(text: "Finish", onButtonPressed: {
                        self.viewModel.onConfirmButtonPressed()
                        self.dismiss()
                    })
                }
                .padding([.leading, .trailing], 16)
                .padding(.bottom, 60)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Personal data")
            .background(ColorPalette.primaryBG)
            .addSystemCloseButton(color: ColorPalette.primaryText,
                                  onPress: {
                self.dismiss()
            })
        }
        .onAppear(perform: self.viewModel.onAppear)
    }
    
    private var headerView: some View {
        Text("Enter your data to allow us to help you fill in the forms faster")
            .multilineTextAlignment(.center)
            .foregroundColor(ColorPalette.primaryText)
            .font(forCategory: .body2)
            .textCase(nil)
            .frame(maxWidth: .infinity)
    }
    
    private func getTextField(
        name: String,
        text: Binding<String>,
        textContentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        Section(header:Text(name)
            .font(forCategory: .caption1)
            .foregroundColor(ColorPalette.primaryText)
        ) {
            TextField("Add \(name)", text: text)
                .frame(maxWidth: .infinity)
                .font(forCategory: .body2)
                .foregroundColor(ColorPalette.primaryText)
                .textContentType(textContentType)
                .keyboardType(keyboardType)
        }
    }
}

struct SuggestedFieldsFormView_Previews: PreviewProvider {
    static var previews: some View {
        SuggestedFieldsFormView()
    }
}
