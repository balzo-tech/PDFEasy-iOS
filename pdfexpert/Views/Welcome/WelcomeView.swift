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
            self.subtitle
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
        // A window is wider than any phone, and a full-width Start button in it
        // reads as a phone control stretched to fit.
        .readableColumn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
    }
}

extension WelcomeView {

    /// The line under the title names the machine the app is running on. Left as
    /// it was, the Mac would be greeted by an app introducing itself as being
    /// for a phone and a tablet.
    @ViewBuilder private var subtitle: some View {
        if UIDevice.isMac {
            Text("The PDF editor for your Mac")
        } else {
            Text("The PDF editor for iPhone and iPad")
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
