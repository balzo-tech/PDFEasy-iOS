//
//  ProfileView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/04/23.
//

import SwiftUI

struct DisclamerItem: Hashable {
    let text: String
    let urlString: String
}

struct ProfileView: View {
    
    @Environment(\.dismiss) var dismiss
    
    private let disclamers = [
        DisclamerItem(text: "Privacy policy", urlString: K.Misc.PrivacyPolicyUrlString),
        DisclamerItem(text: "Terms and conditions", urlString: K.Misc.TermsAndConditionsUrlString)
    ]
    
    var body: some View {
        List(self.disclamers, id: \.self) { disclamer in
                Link(destination: URL(string: disclamer.urlString)!) {
                    HStack {
                        Text(disclamer.text)
                            .font(FontPalette.fontRegular(withSize: 16))
                            .foregroundColor(ColorPalette.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.body)
                            .foregroundColor(ColorPalette.primaryText)
                    }
                }
                .listRowBackground(Color(.clear))
        }
        .padding(.top, 16)
        .listStyle(.plain)
        .background(ColorPalette.primaryBG)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { self.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, weight: .bold))
                        .foregroundColor(ColorPalette.primaryText)
                }
            }
            ToolbarItem(placement: .principal) {
                    Text("Profile")
                    .font(FontPalette.fontRegular(withSize: 16))
                    .foregroundColor(ColorPalette.primaryText)
                        .accessibilityAddTraits(.isHeader)
                }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView()
        }

    }
}
