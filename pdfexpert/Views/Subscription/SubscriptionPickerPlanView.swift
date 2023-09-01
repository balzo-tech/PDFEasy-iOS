//
//  SubscriptionPickerPlanView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 09/08/23.
//

import SwiftUI

struct SubscriptionPickerPlanView: View {
    
    let subscriptionPlanPickerItem: SubscriptionPlanPickerItem?
    let pickerButtonPressed: () -> ()
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Text(self.subscriptionPlanPickerItem?.title ?? "")
                        .font(forCategory: .body1)
                        .foregroundColor(ColorPalette.primaryText)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    self.checkmark
                }
                Spacer()
                Text("Maximum flexibility, you decide\nhow long to stay")
                    .font(forCategory: .caption2)
                    .foregroundColor(ColorPalette.thirdText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                Spacer()
                HStack {
                    Text(self.subscriptionPlanPickerItem?.weeklyPriceAndPeriod ?? "")
                        .font(forCategory: .caption2)
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    self.pickerView
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 134)
        .background(RoundedRectangle(cornerRadius: 10).foregroundColor(ColorPalette.secondaryBG))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(ColorPalette.buttonGradientStart, lineWidth: 2))
        .padding([.leading, .trailing], 1)
    }
    
    private var checkmark: some View {
        ZStack {
            Circle().fill(.white)
                .padding(4)
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .foregroundColor(ColorPalette.buttonGradientStart)
        }.frame(width: 24, height: 24)
    }
    
    private var pickerView: some View {
        Button(action: { self.pickerButtonPressed() }) {
            HStack(spacing: 12) {
                Text(self.subscriptionPlanPickerItem?.period ?? "")
                    .font(forCategory: .callout)
                    .foregroundColor(ColorPalette.primaryText)
                Image(systemName: "chevron.down")
                    .foregroundColor(ColorPalette.primaryText)
            }
            .padding(.leading, 21)
            .padding(.trailing, 16)
        }
        .frame(height: 26)
        .background(Capsule().foregroundColor(ColorPalette.buttonGradientStart))
    }
}

struct SubscriptionPickerPlanView_Previews: PreviewProvider {
    
    private static let subscriptionPlanYearly = {
        SubscriptionPlanPickerItem(
            product: nil,
            title: "Premium 1 year",
            period: "Yearly",
            weeklyPriceAndPeriod: "$1,38/week",
            fullDescriptionText: "Free for 7 days, then $89.99/year",
            priceText: "$89.99",
            bestDiscountText: "53% DISCOUNT"
        )
    }()
    
    static var previews: some View {
        SubscriptionPickerPlanView(subscriptionPlanPickerItem: Self.subscriptionPlanYearly,
                                   pickerButtonPressed: { print("Picker Button Pressed") })
    }
}
