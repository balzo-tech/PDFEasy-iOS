//
//  View+Internal.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 13/03/23.
//

import Foundation
import SwiftUI
import Factory

enum DisclamerType: Hashable, Identifiable {
    case privacyPolicy, termsAndConditions
    
    var id: Self { self }
}

extension View {
    
    var defaultGradientBackground: some View {
        LinearGradient(colors: [ColorPalette.buttonGradientStart, ColorPalette.buttonGradientEnd],
                       startPoint: UnitPoint(x: 0.25, y: 0.5), endPoint: UnitPoint(x: 0.75, y: 0.5))
    }
    
    @ViewBuilder func getDefaultButton(text: String, onButtonPressed: @escaping () -> ()) -> some View {
        Button(action: onButtonPressed) {
            Text(text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .font(FontPalette.fontMedium(withSize: 18))
                .foregroundColor(ColorPalette.primaryText)
                .contentShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(self.defaultGradientBackground)
        .cornerRadius(10)
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
    
    @ViewBuilder func getSubscriptionView(onComplete: @escaping () -> ()) -> some View {
        switch Container.shared.configService().remoteConfigData.value.subcriptionViewType {
        case .pairs: SubscriptionPairsView(onComplete: onComplete)
        case .verticalHighlightLongPeriod:
            let viewModel = Container.shared.subscriptionVerticalViewModel(.highlightLongPeriod)
            SubscriptionVerticalView(viewModel: viewModel, onComplete: onComplete)
        case .verticalHighlightShortPeriod:
            let viewModel = Container.shared.subscriptionVerticalViewModel(.highlightShortPeriod)
            SubscriptionVerticalView(viewModel: viewModel, onComplete: onComplete)
        case .picker: SubscriptionPickerView(onComplete: onComplete)
        }
    }
    
    func showSubscriptionView(_ show: Binding<Bool>, onComplete: @escaping () -> ()) -> some View {
        self.fullScreenCover(isPresented: show) {
            getSubscriptionView(onComplete: {
                show.wrappedValue = false
                onComplete()
            })
        }
    }
    
    func sharePdf(_ pdf: Binding<Pdf?>, applyPostProcess: Bool, onDismiss: @escaping () -> ()) -> some View {
        self.sheet(item: pdf, onDismiss: {
            if let pdf = pdf.wrappedValue {
                PDFUtility.cleanSharedPdf(pdf: pdf)
            }
            onDismiss()
        }) { pdf in
            ActivityViewController(activityItems: [PDFUtility.processToShare(pdf: pdf, applyPostProcess: applyPostProcess)],
                                   thumbnail: pdf.thumbnail,
                                   title: pdf.filename)
        }
    }
    
    func pageCounter(currentPageIndex: Int, totalPages: Int) -> some View {
        Text("\(currentPageIndex + 1) of \(totalPages)")
            .font(FontPalette.fontMedium(withSize: 16))
            .foregroundColor(ColorPalette.primaryText)
    }
    
    func removePasswordView(show: Binding<Bool>,
                            removePasswordCallback: @escaping () -> ()) -> some View {
        self.alert("Would you like to remove your password?", isPresented: show, actions: {
            Button("Delete", role: .destructive, action: removePasswordCallback)
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("If you decide to remove the password, your PDF will no longer be protected.")
        })
    }
    
    func showError<T: LocalizedError>(_ errorBinding: Binding<T?>) -> some View {
        self.alert("Error",
                   isPresented: .constant(errorBinding.wrappedValue != nil),
                   presenting: errorBinding.wrappedValue,
                   actions: { pdfSaveError in
            Button("Ok") { errorBinding.wrappedValue = nil }
        }, message: { error in
            Text(error.errorDescription ?? "")
        })
    }
}
