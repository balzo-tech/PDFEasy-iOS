//
//  HomeItemView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import SwiftUI

struct HomeItemView: View {
    
    let title: String
    let imageName: String
    let onButtonPressed: () -> ()
    
    var body: some View {
        Button(action: {
            self.onButtonPressed()
        }) {
            GeometryReader { geometryReader in
                VStack(spacing: 16) {
                    Spacer()
                    Image(self.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: geometryReader.size.height * 0.2)
                    
                    Text(self.title)
                        .font(FontPalette.fontBold(withSize: 16))
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Spacer()
                }
            }
        }
        .background(
            self.defaultGradientBackground
            .cornerRadius(10)
        )
    }
}

struct HomeItemView_Previews: PreviewProvider {
    static var previews: some View {
        HomeItemView(title: "Convert\nimages to PDF",
                     imageName: "home_convert_image",
                     onButtonPressed: {})
    }
}
