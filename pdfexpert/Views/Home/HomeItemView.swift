//
//  HomeItemView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/03/23.
//

import SwiftUI

struct HomeItemView: View {
    
    let title: String
    let description: String
    let imageName: String
    let onButtonPressed: () -> ()
    
    var body: some View {
        Button(action: {
            self.onButtonPressed()
        }) {
            GeometryReader { geometryReader in
                VStack(spacing: 0) {
                    Spacer()
                    Image(self.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: geometryReader.size.height * 0.2)
                    Spacer().frame(height: 16)
                    Text(self.title)
                        .font(FontPalette.fontMedium(withSize: 16))
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding([.leading, .trailing], 12)
                    Spacer().frame(height: 4)
                    VStack {
                        Text(self.description)
                            .font(FontPalette.fontLight(withSize: 12))
                            .foregroundColor(ColorPalette.primaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding([.leading, .trailing], 12)
                        Spacer()
                    }
                    .frame(height: 65)
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
        GeometryReader { geometryReader in
            HomeItemView(title: "Powerpoint to PDF",
                         description: "Make PPT file easy to view by converting them to PDF converting them to PDF",
                         imageName: "home_image_to_pdf",
                         onButtonPressed: {})
            .aspectRatio(1.0, contentMode: .fit)
            .frame(width: geometryReader.size.width * 0.5)
        }
    }
}
