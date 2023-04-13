//
//  SubscriptionVerticalItemView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 12/04/23.
//

import SwiftUI

struct SubscriptionVerticalItemView: View {
    
    let subscriptionPlan: SubscriptionPlanVerticalItem
    let isSelected: Bool
    let onTap: (() -> ())
    
    var body: some View {
        Button(action: {
            self.onTap()
        }) {
            ZStack {
                HStack(spacing: 12) {
                    self.checkmark
                    VStack(spacing: 4) {
                        if let freeTrialText = self.subscriptionPlan.freeTrialText {
                            Text(freeTrialText)
                                .font(FontPalette.fontBold(withSize: 16))
                                .foregroundColor(ColorPalette.extra)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                        }
                        Text(self.subscriptionPlan.titleShort)
                            .font(FontPalette.fontBold(withSize: 16))
                            .foregroundColor(ColorPalette.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                        Text(self.subscriptionPlan.descriptionText)
                            .font(FontPalette.fontMedium(withSize: 10))
                            .foregroundColor(ColorPalette.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                    }
                }
                .padding([.leading, .trailing], 16)
                .frame(maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                    isSelected ? ColorPalette.buttonGradientStart : ColorPalette.thirdText,
                    lineWidth: 2)
                )
                if let discountText = self.subscriptionPlan.discountText {
                    HStack {
                        Spacer()
                        GeometryReader { geometry in
                            HStack {
                                Spacer()
                                Text(discountText)
                                    .font(FontPalette.fontBold(withSize: 12))
                                    .foregroundColor(.black)
                                    .frame(alignment: .trailing)
                                    .padding([.leading, .trailing], 6)
                                    .padding([.bottom, .top], 2)
                                    .background(ColorPalette.extra)
                                    .cornerRadius(2)
                            }.position(x: geometry.size.width/2, y: 0)
                        }
                    }
                    .padding([.trailing], 16)
                }
            }
        }
        .frame(height: self.viewHeight)
    }
    
    var viewHeight: CGFloat {
        self.subscriptionPlan.freeTrialText != nil ? 86 : 76
    }
    
    var checkmark: some View {
        ZStack {
            if self.isSelected {
                Image(systemName: "circle.fill")
                    .resizable()
                    .foregroundColor(.white)
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .foregroundColor(ColorPalette.buttonGradientStart)
            } else {
                Image(systemName: "circle")
                    .resizable()
                    .foregroundColor(ColorPalette.thirdText)
            }
        }.frame(width: 24, height: 24)
    }
}

struct SubscriptionVerticalItemView_Previews: PreviewProvider {
    private static let subscriptionPlanYearly = {
        SubscriptionPlanVerticalItem(product: nil,
                                     titleShort: "Yearly",
                                     descriptionText: "$1,38/week",
                                     fullDescriptionText: "Free for 7 days, then $89.99/year",
                                     freeTrialText: "FREE TRIAL for 7 days",
                                     discountText: "53% DISCOUNT"
        )
    }()
    private static let subscriptionPlanMonthly = {
        SubscriptionPlanVerticalItem(product: nil,
                                     titleShort: "Monthly",
                                     descriptionText: "$2,47/week",
                                     fullDescriptionText: "$89.99/month",
                                     freeTrialText: nil,
                                     discountText: nil
        )
    }()
    private static let subscriptionPlanWeekly = {
        SubscriptionPlanVerticalItem(product: nil,
                                     titleShort: "Weekly",
                                     descriptionText: "$4,99/week",
                                     fullDescriptionText: "$4,99/week",
                                     freeTrialText: nil,
                                     discountText: nil
        )
    }()
    
    static var previews: some View {
        VStack(spacing: 16) {
            Spacer()
            SubscriptionVerticalItemView(subscriptionPlan: Self.subscriptionPlanYearly,
                                 isSelected: true,
                                 onTap: {})
            SubscriptionVerticalItemView(subscriptionPlan: Self.subscriptionPlanMonthly,
                                 isSelected: false,
                                 onTap: {})
            SubscriptionVerticalItemView(subscriptionPlan: Self.subscriptionPlanWeekly,
                                 isSelected: false,
                                 onTap: {})
            Spacer()
        }
        .padding([.leading, .trailing], 16)
        .background(ColorPalette.primaryBG)
    }
}
