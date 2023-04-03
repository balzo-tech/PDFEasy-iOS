//
//  SubscriptionErrorView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/04/23.
//

import SwiftUI

struct SubscriptionErrorView: View {
    
    var onButtonPressed: () -> ()
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("subscription_error")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            Text("Oh nou")
                .font(FontPalette.fontBold(withSize: 32))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Something went wrong,\nmind trying again?")
                .font(FontPalette.fontRegular(withSize: 15))
                .foregroundColor(ColorPalette.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
            Button(action: {
                self.onButtonPressed()
            }) {
                Text("Retry")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .font(FontPalette.fontBold(withSize: 16))
                    .foregroundColor(ColorPalette.primaryText)
                    .contentShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(self.defaultGradientBackground)
            .cornerRadius(10)
        }
        .padding([.leading, .trailing], 16)
        .padding([.top, .bottom], 64)
    }
}

struct SubscriptionErrorView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionErrorView(onButtonPressed: {})
            .background(ColorPalette.primaryBG)
    }
}
