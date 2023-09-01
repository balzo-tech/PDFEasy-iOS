//
//  SubscriptionVerticalView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 12/04/23.
//

import SwiftUI
import Factory

struct SubscriptionVerticalView: View {
    
    @StateObject var viewModel: SubscriptionVerticalViewModel
    
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
        switch self.viewModel.asyncSubscriptionPlanList.status {
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
                Text("No obligation, you can cancel whenever you want.")
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            VStack(spacing: 0) {
                Spacer().frame(height: 20)
                self.subscriptionPlansView
                Spacer().frame(height: 4)
            }
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
    
    var currentSubscriptionPlanView: some View {
        Text(self.viewModel.currentSubscriptionPlan?.fullDescriptionText ?? "")
            .font(forCategory: .headline)
            .foregroundColor(ColorPalette.primaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 40)
            .minimumScaleFactor(0.5)
    }
    
    var subscriptionPlansView: some View {
        if let subscriptionPlanList = self.viewModel.asyncSubscriptionPlanList.data {
            return AnyView(
                ForEach(Array(subscriptionPlanList.enumerated()), id: \.offset) { index, subscriptionPlanVerticalItem in
                    SubscriptionVerticalItemView(subscriptionPlan: subscriptionPlanVerticalItem,
                                                 isSelected: self.viewModel.selectedSubscriptionItemIndex == index,
                                                 onTap: { self.viewModel.selectedSubscriptionItemIndex = index })
                    .frame(maxHeight: 200)
                    Spacer().frame(height: 16)
                }
            )
        } else {
            return AnyView(Spacer().frame(height: 1))
        }
    }
}

struct SubscriptionVerticalView_Previews: PreviewProvider {
    
    static let highlightLongPeriodViewModel = SubscriptionVerticalViewModel(mode: .highlightLongPeriod)
    static let highlightShortPeriodViewModel = SubscriptionVerticalViewModel(mode: .highlightShortPeriod)
    
    static var previews: some View {
        SubscriptionVerticalView(viewModel: Self.highlightLongPeriodViewModel,
                                 onComplete: { print("Complete!") })
        .previewDisplayName("Highlight Long Period")
        SubscriptionVerticalView(viewModel: Self.highlightShortPeriodViewModel,
                                 onComplete: { print("Complete!") })
        .previewDisplayName("Highlight Short Period")
    }
}
