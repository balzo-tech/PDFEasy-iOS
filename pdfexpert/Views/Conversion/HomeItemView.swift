//
//  HomeItemView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import SwiftUI

struct HomeItemView: View {
    
    let title: String
    let buttonText: String
    let onButtonPressed: () -> ()
    
    var body: some View {
        ZStack {
            self.defaultGradientBackground
            .foregroundColor(ColorPalette.secondaryBG)
            .cornerRadius(10)
            .shadow(radius: 5)
            VStack(spacing: 0) {
                Text(self.title)
                    .font(FontPalette.fontBold(withSize: 28))
                    .foregroundColor(ColorPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Button(action: {
                    self.onButtonPressed()
                }) {
                    Text(self.buttonText)
                        .font(FontPalette.fontBold(withSize: 16))
                        .foregroundColor(ColorPalette.buttonGradientStart)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(ColorPalette.primaryText)
                .cornerRadius(10)
                .shadow(radius: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(height: 175)
        .padding(.leading, 24)
        .padding(.trailing, 24)
    }
}

struct HomeItemView_Previews: PreviewProvider {
    static var previews: some View {
        HomeItemView(title: "Convert\npicture to PDF",
                     buttonText: "Start to convert",
                     onButtonPressed: {})
    }
}
