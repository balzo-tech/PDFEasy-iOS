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
            // The ZStack is needed to disable keyboard avoiding for the footer
            // while keeping it for the textfields in the content view
            ZStack {
                self.contentView
                self.footerView
                    .ignoresSafeArea(.keyboard)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Personal data")
            .background(ColorPalette.primaryBG)
            .addSystemCloseButton(color: ColorPalette.primaryText,
                                  onPress: {
                self.dismiss()
            })
        }
        .background(ColorPalette.primaryBG)
        .onAppear(perform: self.viewModel.onAppear)
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            Form {
                Section(header: self.headerView) {}
                self.getTextField(name: "First Name",
                                  text: self.$viewModel.firstName,
                                  textContentType: .givenName)
                self.getTextField(name: "Last Name",
                                  text: self.$viewModel.lastName,
                                  textContentType: .familyName)
                self.getTextField(name: "Address",
                                  text: self.$viewModel.address,
                                  textContentType: .streetAddressLine1)
                self.getTextField(name: "City",
                                  text: self.$viewModel.city,
                                  textContentType: .addressCity)
                self.getTextField(name: "Country",
                                  text: self.$viewModel.country,
                                  textContentType: .countryName)
                self.getTextField(name: "Email",
                                  text: self.$viewModel.email,
                                  textContentType: .emailAddress,
                                  keyboardType: .emailAddress)
                self.getTextField(name: "Phone",
                                  text: self.$viewModel.phone,
                                  textContentType: .telephoneNumber,
                                  keyboardType: .phonePad)
                // This space is needed to create an inset equivalent to the footerView height
                Spacer().frame(height: 90)
                    .listRowBackground(ColorPalette.primaryBG)
            }
            .foregroundColor(ColorPalette.primaryText)
            .background(ColorPalette.primaryBG)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Spacer()
            self.getDefaultButton(text: "Finish", onButtonPressed: {
                self.viewModel.onConfirmButtonPressed()
                self.dismiss()
            })
            .padding([.top, .leading, .trailing], 16)
            .padding(.bottom, 80)
            .background(ColorPalette.primaryBG)
        }
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
        .listRowBackground(ColorPalette.secondaryBG)
    }
}

struct SuggestedFieldsFormView_Previews: PreviewProvider {
    static var previews: some View {
        SuggestedFieldsFormView()
    }
}
