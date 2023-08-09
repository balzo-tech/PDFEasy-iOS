//
//  SubscriptionFreeTrialToggleView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 09/08/23.
//

import SwiftUI

struct SubscriptionFreeTrialToggleView: View {
    
    @Binding var isFreeTrial: Bool
    
    var body: some View {
        Button(action: {
            self.isFreeTrial.toggle()
        }) {
            HStack {
                self.freeTrialDescriptionView
                self.checkmark
            }
            .padding([.leading, .trailing], 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(RoundedRectangle(cornerRadius: 10)
            .foregroundColor(ColorPalette.secondaryBG))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(self.isFreeTrial ? ColorPalette.buttonGradientStart : .clear, lineWidth: 2))
    }
    
    var freeTrialDescriptionView: some View {
        return VStack(spacing: 0) {
            Text("Not sure yet?")
                .font(FontPalette.fontMedium(withSize: 16))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(height: 4)
            Text("Enable the free trial")
                .font(FontPalette.fontRegular(withSize: 12))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    var checkmark: some View {
        Group {
            if self.isFreeTrial {
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .foregroundColor(ColorPalette.buttonGradientStart)
            } else {
                Image(systemName: "circle")
                    .resizable()
                    .foregroundColor(ColorPalette.thirdText)
            }
        }.frame(width: 22, height: 22)
    }
}

struct SubscriptionFreeTrialToggleView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionFreeTrialToggleView(isFreeTrial: .constant(true))
    }
}
