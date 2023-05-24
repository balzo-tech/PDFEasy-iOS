//
//  SubscriptionPairsView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/03/23.
//

import SwiftUI
import Factory

struct SubscriptionPairsView: View {
    
    @InjectedObject(\.subscribtionPairsViewModel) var viewModel
    var onComplete: () -> ()
    
    var body: some View {
        ZStack {
            self.getCloseButton(color: ColorPalette.primaryText.opacity(0.3)) {
                self.onComplete()
            }
            self.content
        }
        .background(ColorPalette.primaryBG)
        .asyncView(asyncOperation: self.$viewModel.purchaseRequest)
        .asyncView(asyncOperation: self.$viewModel.restorePurchaseRequest)
        .onAppear() {
            self.viewModel.onAppear()
        }
        .onChange(of: self.viewModel.isPremium, perform: { newValue in
            if newValue {
                self.onComplete()
            }
        })
    }
    
    var content: some View {
        switch self.viewModel.asyncSubscriptionPlanPairs.status {
        case .empty: return AnyView(Spacer())
        case .loading: return AnyView(AnimationType.dots.view.loop())
        case .data: return AnyView(self.mainView)
        case .error: return AnyView(SubscriptionErrorView(onButtonPressed: {
            self.viewModel.refresh()
        }))
        }
    }
    
    var mainView: some View {
        VStack(spacing: 0) {
            self.restorePurchaseButton
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
                Text("PDF Easy")
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
            self.freeTrialView
            Spacer().frame(height: 20)
            self.getDefaultButton(text: "Subscribe",
                                  onButtonPressed: { self.viewModel.subscribe() })
            self.currentSubscriptionPlanView
        }
        .padding([.leading, .trailing], 16)
    }
    
    var restorePurchaseButton: some View {
        Button(action: { self.viewModel.restorePurchases() }) {
            Text("Restore purchase")
                .frame(maxHeight: .infinity)
                .underline()
                .font(FontPalette.fontRegular(withSize: 15))
                .foregroundColor(ColorPalette.primaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
    
    var freeTrialView: some View {
        let view: AnyView
        if let currentSubscriptionPlanPair = self.viewModel.currentSubscriptionPlanPair,
           currentSubscriptionPlanPair.standardSubscriptionPlan != nil,
           currentSubscriptionPlanPair.freeTrialSubscriptionPlan != nil {
            view = AnyView(
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
                        .stroke(self.viewModel.isFreeTrialEnabled
                                ? ColorPalette.buttonGradientStart
                                : .clear,
                                lineWidth: 2))
            )
        } else {
            view = AnyView(Spacer())
        }
        return view.frame(height: 62)
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
        if self.viewModel.isFreeTrialEnabled {
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
        Text(self.viewModel.currentSubscriptionPlan?.fullDescriptionText ?? "")
            .font(FontPalette.fontBold(withSize: 18))
            .foregroundColor(ColorPalette.primaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 40)
            .minimumScaleFactor(0.5)
    }
    
    var subscriptionPlanPairsView: some View {
        if let subscriptionPlanPairs = self.viewModel.asyncSubscriptionPlanPairs.data {
            return AnyView(HStack(spacing: 16) {
                ForEach(Array(subscriptionPlanPairs.enumerated()), id: \.offset) { index, subscriptionPlanPair in
                    if let subscriptionPlan = self.getSubscriptionPlan(from: subscriptionPlanPair) {
                        SubscriptionPairsItemView(subscriptionPlan: subscriptionPlan,
                                             isSelected: self.viewModel.selectedSubscriptionPairIndex == index,
                                             onTap: { self.viewModel.selectedSubscriptionPairIndex = index })
                    }
                }
            }
            .frame(height: 161))
        } else {
            return AnyView(Spacer().frame(height: 1))
        }
    }
    
    func onFreeTrialSwitchPressed() {
        self.viewModel.isFreeTrialEnabled = !self.viewModel.isFreeTrialEnabled
    }
    
    func getSubscriptionPlan(from subscriptionPlanPair: SubscriptionPlanPair) -> SubscriptionPlanPairItem? {
        if self.viewModel.isFreeTrialEnabled {
            return subscriptionPlanPair.freeTrialSubscriptionPlan ?? subscriptionPlanPair.standardSubscriptionPlan
        } else {
            return subscriptionPlanPair.standardSubscriptionPlan ?? subscriptionPlanPair.freeTrialSubscriptionPlan
        }
    }
}

struct SubscriptionPairsView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionPairsView(onComplete: {})
    }
}
