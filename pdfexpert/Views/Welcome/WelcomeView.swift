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
                    Image("logo_large")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 600)
                        .padding(60)
                    Text("Welcome in \(K.Misc.AppTitle):\nConvert & Edit")
                        .font(forCategory: .title1)
                        .foregroundColor(ColorPalette.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("The PDF editor for iPhone")
                        .font(forCategory: .headline)
                        .foregroundColor(ColorPalette.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .position(x: geometry.size.width/2, y: geometry.size.height/3)
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
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
