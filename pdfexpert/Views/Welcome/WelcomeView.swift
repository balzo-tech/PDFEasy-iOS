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
        VStack(spacing: DS.Spacing.md) {
            Spacer(minLength: DS.Spacing.xl)
            Image("logo_large")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320, maxHeight: 320)
            Spacer(minLength: DS.Spacing.lg)
            Text("Welcome in \(K.Misc.AppTitle):\nConvert & Edit")
                .font(forCategory: .largeTitle)
                .foregroundStyle(ColorPalette.textPrimary)
                .multilineTextAlignment(.center)
            Text("The PDF editor for iPhone")
                .font(forCategory: .body1)
                .foregroundStyle(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: DS.Spacing.xl)
            self.getDefaultButton(text: String(localized: "Start"),
                                  onButtonPressed: self.coordinator.showOnboarding)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.xxl)
        .padding(.bottom, DS.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
