//
//  SubscriptionPickerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 08/08/23.
//

import SwiftUI
import Factory

struct SubscriptionPickerView: View {
    
    fileprivate struct SubscriptionFeature: Hashable {
        let imageName: String
        let text: String
    }
    
    private let subscriptionFeatures: [SubscriptionFeature] = [
        SubscriptionFeature(imageName: "subscription_feature_convert",
                       text: "Convert file to PDF"),
        SubscriptionFeature(imageName: "subscription_feature_chat_pdf",
                       text: "Ask any question to PDF and get insights fast"),
        SubscriptionFeature(imageName: "subscription_feature_signature",
                       text: "Enter and edit your signature"),
        SubscriptionFeature(imageName: "subscription_feature_password",
                       text: "Protect your files with password"),
        SubscriptionFeature(imageName: "subscription_feature_edit",
                       text: "Edit, save and share your PDF"),
    ]
    
    @InjectedObject(\.subscriptionPickerViewModel) var viewModel
    
    @State var showPlansPicker: Bool = false
    
    var onComplete: () -> ()
    
    var body: some View {
        ZStack {
            self.getCloseButton(color: ColorPalette.primaryText.opacity(0.3)) {
                self.onComplete()
            }
            self.content
        }
        .background(ColorPalette.primaryBG)
        .asyncView(asyncItem: self.$viewModel.purchaseRequest)
        .asyncView(asyncItem: self.$viewModel.restorePurchaseRequest)
        .onAppear() {
            self.viewModel.onAppear()
        }
        .sheetAutoHeight(isPresented: self.$showPlansPicker,
                         backgroundColor: ColorPalette.secondaryBG,
                         topCornerRadius: 10,
                         content: {
            SubscriptionPickerPlanListView(viewModel: self.viewModel)
        })
        .onChange(of: self.viewModel.isPremium, perform: { newValue in
            if newValue {
                self.onComplete()
            }
        })
    }
    
    @ViewBuilder var content: some View {
        switch self.viewModel.asyncSubscriptionPlanPairs.status {
        case .empty: Spacer()
        case .loading: AnimationType.dots.view
        case .data: self.mainView
        case .error: SubscriptionErrorView(onButtonPressed: {
            self.viewModel.refresh()
        })
        }
    }
    
    var mainView: some View {
        VStack(spacing: 0) {
            self.restorePurchaseButton
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 26)
                    Text("Choose a plan")
                        .font(FontPalette.fontMedium(withSize: 16))
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(height: 26)
                    SubscriptionPickerPlanView(subscriptionPlanPickerItem: self.viewModel.currentSubscriptionPlan,
                                               pickerButtonPressed: {
                        self.showPlansPicker = true
                    })
                    Spacer().frame(height: 20)
                    Spacer()
                }
                VStack(spacing: 0) {
                    Text("What you get")
                        .font(FontPalette.fontMedium(withSize: 16))
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(height: 16)
                    ForEach(self.subscriptionFeatures, id:\.self) { feature in
                        VStack(spacing: 0) {
                            self.getSubscriptionFeature(feature: feature)
                            ColorPalette.fourthText.frame(height: 1)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            VStack(spacing: 0) {
                self.freeTrialView
                self.getDefaultButton(text: "Continue",
                                      onButtonPressed: { self.viewModel.subscribe() })
                self.currentSubscriptionPlanView
            }
            .background(ColorPalette.primaryBG)
            .padding(.top, 16)
        }
        .padding([.leading, .trailing], 16)
    }
    
    private var restorePurchaseButton: some View {
        Button(action: { self.viewModel.restorePurchases() }) {
            Text("Restore purchase")
                .frame(maxHeight: .infinity)
                .underline()
                .font(FontPalette.fontLight(withSize: 14))
                .foregroundColor(ColorPalette.primaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
    
    private func getSubscriptionFeature(feature: SubscriptionFeature) -> some View {
        HStack(spacing: 16) {
            Image(feature.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            Text(feature.text)
                .font(FontPalette.fontRegular(withSize: 12))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22).bold())
                .foregroundColor(ColorPalette.buttonGradientStart)
        }
        .frame(height: 52)
    }
    
    private var freeTrialView: some View {
        VStack(spacing: 0) {
            if let currentSubscriptionPlanPair = self.viewModel.currentSubscriptionPlanPair,
               currentSubscriptionPlanPair.standardSubscriptionPlan != nil,
               currentSubscriptionPlanPair.freeTrialSubscriptionPlan != nil {
                SubscriptionFreeTrialToggleView(isFreeTrial: self.$viewModel.isFreeTrialEnabled)
                Spacer().frame(height: 20)
            }
        }
    }
    
    private var currentSubscriptionPlanView: some View {
        Text(self.viewModel.currentSubscriptionPlan?.fullDescriptionText ?? "")
            .font(FontPalette.fontMedium(withSize: 18))
            .foregroundColor(ColorPalette.primaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 40)
            .minimumScaleFactor(0.5)
    }
}

struct SubscriptionPickerView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionPickerView(onComplete: {})
    }
}
