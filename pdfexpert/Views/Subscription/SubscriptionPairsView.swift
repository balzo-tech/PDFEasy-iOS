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
        case .loading: return AnyView(AnimationType.dots.view)
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
                Image("logo_large")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                Spacer().frame(height: 20)
                Spacer()
            }
            VStack(spacing: 0) {
                Text(K.Misc.AppTitle)
                    .font(forCategory: .largeTitle)
                    .foregroundColor(ColorPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(height: 16)
                Text("Edit, convert PDFs and receive constant updates and advanced Premium features. ")
                    .font(forCategory: .body1)
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
            self.getDefaultButton(text: "Continue",
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
                .font(forCategory: .linkText)
                .foregroundColor(ColorPalette.primaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
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
    
    var currentSubscriptionPlanView: some View {
        Text(self.viewModel.currentSubscriptionPlan?.fullDescriptionText ?? "")
            .font(forCategory: .headline)
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
                .frame(minHeight: 161, maxHeight: 200))
        } else {
            return AnyView(Spacer().frame(height: 1))
        }
    }
    
    func getSubscriptionPlan(from subscriptionPlanPair: SubscriptionPairsViewModel.PlanPair) -> SubscriptionPlanPairItem? {
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
