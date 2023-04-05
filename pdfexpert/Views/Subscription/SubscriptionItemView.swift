//
//  SubscriptionItemView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/03/23.
//

import SwiftUI

struct SubscriptionItemView: View {
    
    let subscriptionPlan: SubscriptionPlan
    let isSelected: Bool
    let onTap: (() -> ())
    
    var body: some View {
        Button(action: {
            self.onTap()
        }) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Text(self.subscriptionPlan.title)
                        .font(FontPalette.fontBold(withSize: 16))
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: 110, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    self.checkmark
                }
                Spacer().frame(height: 6)
                Text("Maximum flexibility, you decide when to cancel")
                    .font(FontPalette.fontRegular(withSize: 10))
                    .foregroundColor(ColorPalette.thirdText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                Spacer().frame(minHeight: 12)
                Text(self.subscriptionPlan.descriptionText)
                    .font(FontPalette.fontBold(withSize: 12))
                    .foregroundColor(ColorPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding([.leading, .trailing, .top], 12)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).foregroundColor(ColorPalette.secondaryBG))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(self.isSelected ? ColorPalette.buttonGradientStart : ColorPalette.thirdText, lineWidth: 2))
    }
    
    var checkmark: some View {
        Group {
            if self.isSelected {
                AnyView(Image(systemName: "checkmark.circle")
                    .resizable()
                    .foregroundColor(ColorPalette.buttonGradientStart))
            } else {
                AnyView(Spacer())
            }
        }.frame(width: 22, height: 22)
    }
}

struct SubscriptionItemView_Previews: PreviewProvider {
    
    private static let subscriptionPlanYearly = SubscriptionPlan(product: nil,
                                                           title: "Premium 1 year",
                                                           descriptionText: "$1,38/week",
                                                           fullDescriptionText: "")
    private static let subscriptionPlanMonthly = SubscriptionPlan(product: nil,
                                                           title: "Premium 1 month",
                                                           descriptionText: "$2,09/week",
                                                           fullDescriptionText: "")
    
    static var previews: some View {
        HStack(spacing: 16) {
            SubscriptionItemView(subscriptionPlan: Self.subscriptionPlanYearly,
                                 isSelected: true,
                                 onTap: {})
            SubscriptionItemView(subscriptionPlan: Self.subscriptionPlanMonthly,
                                 isSelected: false,
                                 onTap: {})
        }
        .padding([.leading, .trailing], 16)
        .frame(height: 161)
    }
}