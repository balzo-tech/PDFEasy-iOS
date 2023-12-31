//
//  SettingsView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/04/23.
//

import SwiftUI
import Factory

struct DisclamerItem: Hashable {
    let text: String
    let urlString: String
}

struct SettingsView: View {
    
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
                        .font(forCategory: .body1)
                        .foregroundColor(ColorPalette.primaryText)
                    Spacer()
                    Self.getSystemChevron(color: ColorPalette.primaryText,
                                          directionRight: true)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color(.clear))
        }
        .padding(.top, 16)
        .listStyle(.plain)
        .background(ColorPalette.primaryBG)
        .onAppear() {
            Container.shared.analyticsManager().track(event: .reportScreen(.settings))
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
