//
//  OnboardingPageView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 25/05/23.
//

import SwiftUI

struct OnboardingPageView: View {
    
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(self.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 600)
            Spacer().frame(height: 40)
            Text(self.title)
                .font(FontPalette.fontMedium(withSize: 22))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 70, alignment: .top)
                .padding([.leading, .trailing], 32)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 16)
            Text(self.description)
                .font(FontPalette.fontRegular(withSize: 16))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 80, alignment: .top)
                .padding([.leading, .trailing], 32)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

struct OnboardingPageView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPageView(
            imageName: "onboarding_tutorial_1",
            title: "Convert files\nto PDF",
            description: "You can convert to pdf a lot of file types from the programs you prefer."
        )
        OnboardingPageView(
            imageName: "onboarding_tutorial_2",
            title: "Enter and edit your\nsignature",
            description: "Insert your signature in the pdf you created with a single tap."
        )
        OnboardingPageView(
            imageName: "onboarding_tutorial_3",
            title: "Edit, share and save your\nPDF",
            description: "You can add new pages, edit your pdf, save it and share it with anyone."
        )
        OnboardingPageView(
            imageName: "onboarding_tutorial_4",
            title: "Protect your files with\npassword",
            description: "Enter a password to protect your pdf, you can delete it and change it whenever you want."
        )
    }
}
