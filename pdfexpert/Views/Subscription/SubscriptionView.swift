//
//  SubscriptionView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/03/23.
//

import SwiftUI
import Factory

struct SubscriptionView: View {
    
    @InjectedObject(\.subscribeViewModel) var subscribeViewModel
    @Binding var showModal: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            self.getCloseButton(color: ColorPalette.primaryText) {
                self.showModal = false
            }
            VStack(spacing: 0) {
                restorePurchaseButton
                VStack(spacing: 0) {
                    Spacer()
                    Spacer().frame(height: 20)
                    Image("subscription")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 194)
                    Spacer().frame(height: 20)
                    Spacer()
                }
                VStack(spacing: 0) {
                    Text("PDF PRO")
                        .font(FontPalette.fontBold(withSize: 32))
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(height: 16)
                    Text("Edit, convert PDFs and receive constant updates and advanced Premium features. ")
                        .font(FontPalette.fontRegular(withSize: 15))
                        .foregroundColor(ColorPalette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                VStack(spacing: 0) {
                    Spacer().frame(height: 42)
                    self.subscriptionPlanPairsView
                    Spacer().frame(height: 16)
                }
                Button(action: {
                    self.onFreeTrialSwitchPressed()
                }) {
                    HStack {
                        self.freeTrialDescriptionView
                        self.checkMark
                    }
                    .padding([.leading, .trailing], 16)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(RoundedRectangle(cornerRadius: 10).foregroundColor(ColorPalette.secondaryBG))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(self.subscribeViewModel.isFreeTrialEnabled ? ColorPalette.buttonGradientStart : .clear,
                            lineWidth: 2))
                Spacer().frame(height: 20)
                Button(action: {
                    self.subscribeViewModel.subscribe()
                }) {
                    Text("Subscribe")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .font(FontPalette.fontBold(withSize: 16))
                        .foregroundColor(ColorPalette.primaryText)
                        .contentShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(self.defaultGradientBackground)
                .cornerRadius(10)
                self.currentSubscriptionPlanView
            }
            .padding([.leading, .trailing], 16)
        }
        .background(ColorPalette.primaryBG)
        .asyncView(asyncOperation: self.$subscribeViewModel.purchaseRequest)
        .asyncView(asyncOperation: self.$subscribeViewModel.restorePurchaseRequest)
        .onAppear() {
            self.subscribeViewModel.refresh()
        }
        .onChange(of: self.subscribeViewModel.isPremium, perform: { newValue in
            if newValue {
                self.dismiss()
            }
        })
    }
    
    var restorePurchaseButton: some View {
        Button(action: { self.subscribeViewModel.restorePurchases() }) {
            Text("Restore purchase")
                .frame(maxHeight: .infinity)
                .underline()
                .font(FontPalette.fontRegular(withSize: 15))
                .foregroundColor(ColorPalette.primaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
    
    var freeTrialDescriptionView: some View {
        return AnyView(VStack(spacing: 0) {
            Text("Not sure yet?")
                .font(FontPalette.fontBold(withSize: 16))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(height: 4)
            Text("Enable free trial")
                .font(FontPalette.fontRegular(withSize: 12))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        })
    }
    
    var checkMark: some View {
        let view: AnyView
        if self.subscribeViewModel.isFreeTrialEnabled {
            view = AnyView(
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .foregroundColor(ColorPalette.buttonGradientStart))
        } else {
            view = AnyView(Image(systemName: "circle")
                .resizable()
                .foregroundColor(ColorPalette.thirdText))
        }
        return view
            .frame(width: 22, height: 22)
    }
    
    var currentSubscriptionPlanView: some View {
        Text(self.subscribeViewModel.currentSubscriptionPlan?.fullDescriptionText ?? "")
            .font(FontPalette.fontBold(withSize: 15))
            .foregroundColor(ColorPalette.primaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 40)
    }
    
    var subscriptionPlanPairsView: some View {
        if let subscriptionPlanPairs = self.subscribeViewModel.asyncSubscriptionPlanPairs.data {
            return AnyView(HStack(spacing: 16) {
                ForEach(Array(subscriptionPlanPairs.enumerated()), id: \.offset) { index, subscriptionPlanPair in
                    if let subscriptionPlan = self.getSubscriptionPlan(from: subscriptionPlanPair) {
                        SubscriptionItemView(subscriptionPlan: subscriptionPlan,
                                             isSelected: self.subscribeViewModel.selectedSubscriptionPairIndex == index,
                                             onTap: { self.subscribeViewModel.selectedSubscriptionPairIndex = index })
                    }
                }
            }
            .frame(height: 161))
        } else {
            return AnyView(Spacer().frame(height: 1))
        }
    }
    
    func onFreeTrialSwitchPressed() {
        self.subscribeViewModel.isFreeTrialEnabled = !self.subscribeViewModel.isFreeTrialEnabled
    }
    
    func getSubscriptionPlan(from subscriptionPlanPair: SubscriptionPlanPair) -> SubscriptionPlan? {
        if self.subscribeViewModel.isFreeTrialEnabled {
            return subscriptionPlanPair.freeTrialSubscriptionPlan ?? subscriptionPlanPair.standardSubscriptionPlan
        } else {
            return subscriptionPlanPair.standardSubscriptionPlan ?? subscriptionPlanPair.freeTrialSubscriptionPlan
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView(showModal: .constant(true))
    }
}
