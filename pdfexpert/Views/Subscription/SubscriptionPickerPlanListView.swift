//
//  SubscriptionPickerPlanListView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 10/08/23.
//

import SwiftUI
import Factory

struct SubscriptionPickerPlanListView: View {
    
    @ObservedObject var viewModel: SubscriptionPickerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Choose period")
                .font(forCategory: .button)
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(height: 20)
            ForEach(Array(self.viewModel.subscriptionPlans.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 0) {
                    self.getSubscriptionPlan(subscriptionPlan: item, index: index)
                    Spacer().frame(height: 21)
                }
            }
        }
        .padding([.leading, .trailing], 16)
        .padding(.top, 20)
    }
    
    private func getSubscriptionPlan(subscriptionPlan: SubscriptionPlanPickerItem,
                                     index: Int) -> some View {
        ZStack {
            Button(action: {
                self.dismiss()
                self.viewModel.selectedSubscriptionPairIndex = index
            }) {
                HStack(spacing: 0) {
                    Text(subscriptionPlan.period + " |")
                        .font(forCategory: .button)
                        .foregroundColor(ColorPalette.primaryText)
                    Spacer().frame(width: 6)
                    Text(subscriptionPlan.priceText)
                        .font(forCategory: .button)
                        .foregroundColor(ColorPalette.thirdText)
                    Spacer()
                    Text(subscriptionPlan.weeklyPriceAndPeriod)
                        .font(forCategory: .caption1)
                        .foregroundColor(ColorPalette.thirdText)
                }
                .padding(16)
            }
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(
                    self.viewModel.selectedSubscriptionPairIndex == index
                    ? ColorPalette.buttonGradientStart
                    : ColorPalette.fourthText,
                    lineWidth: self.viewModel.selectedSubscriptionPairIndex == index ? 2 : 1)
            )
            if let bestDiscountText = subscriptionPlan.bestDiscountText {
                HStack {
                    Spacer()
                    GeometryReader { geometry in
                        HStack {
                            Spacer()
                            Text(bestDiscountText)
                                .font(forCategory: .callout)
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
        .padding([.leading, .trailing], 1)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
    }
}

struct SubscriptionPickerPlanListView_Previews: PreviewProvider {
    static var previews: some View {
        Color.white
            .sheetAutoHeight(isPresented: .constant(true),
                             backgroundColor: ColorPalette.secondaryBG,
                             topCornerRadius: 10) {
                SubscriptionPickerPlanListView(viewModel: Container.shared.subscriptionPickerViewModel())
            }
    }
}
