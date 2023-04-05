//
//  View+Internal.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 13/03/23.
//

import Foundation
import SwiftUI

enum DisclamerType: Hashable, Identifiable {
    case privacyPolicy, termsAndConditions
    
    var id: Self { self }
}

extension View {
    
    var defaultGradientBackground: some View {
        LinearGradient(colors: [ColorPalette.buttonGradientStart, ColorPalette.buttonGradientEnd],
                       startPoint: UnitPoint(x: 0.25, y: 0.5), endPoint: UnitPoint(x: 0.75, y: 0.5))
    }
    
    func getDisclamer(color: Color, onSelection: @escaping (DisclamerType) -> ()) -> some View {
        var attributedString = AttributedString("By continuing you accept our ")
        attributedString += Self.getAttributedText(forUrlString: K.Misc.TermsAndConditionsUrlString, text: "Terms and Conditions")
        attributedString += AttributedString(" and confirm that you have received our ")
        attributedString += Self.getAttributedText(forUrlString: K.Misc.PrivacyPolicyUrlString, text: "Privacy Policy")
        attributedString += AttributedString(".")
        return Text(attributedString)
            .multilineTextAlignment(.center)
            .font(FontPalette.fontRegular(withSize: 12))
            .foregroundColor(color)
            .tint(color)
    }
    
    func alertCameraPermission(isPresented: Binding<Bool>) -> some View {
        self.alert("Unable to access camera",
                   isPresented: isPresented) {
            Button("Settings", role: .none) {
                if let appSettingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettingsUrl,
                                              options: [:],
                                              completionHandler: nil)
                                          }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have denied permission to access the camera of your device. Please go to your phone Settings to change your camera permission to be able to scan and convert your documents.")
        }
    }
}
