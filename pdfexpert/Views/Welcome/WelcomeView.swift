//
//  WelcomeView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/04/23.
//

import SwiftUI
import Factory

struct WelcomeView: View {
    
    @Injected(\.mainCoordinator) private var coordinator
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    Image("subscription")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 132)
                    Text("Welcome in PDF Easy:\nConvert & Edit")
                        .font(FontPalette.fontBold(withSize: 24))
                        .foregroundColor(ColorPalette.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("The PDF editor for iPhone")
                        .font(FontPalette.fontRegular(withSize: 18))
                        .foregroundColor(ColorPalette.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .position(x: geometry.size.width/2, y: geometry.size.height/4)
            }
            VStack {
                Spacer()
                self.getDefaultButton(text: "Start",
                                      onButtonPressed: self.coordinator.showOnboarding)
            }
        }
        .padding([.leading, .trailing], 16)
        .padding([.top, .bottom], 64)
        .background(ColorPalette.primaryBG)
        .navigationBarHidden(true)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
