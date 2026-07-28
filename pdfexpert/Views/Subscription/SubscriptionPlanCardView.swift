//
//  SubscriptionPlanCardView.swift
//  PdfExpert
//
//  One plan on the paywall. Name and trial promise on the left, what it costs
//  on the right, so the eye can run down the right-hand edge and compare the
//  two numbers without reading a sentence.
//

import SwiftUI

struct SubscriptionPlanCardView: View {

    let plan: SubscriptionPaywallPlan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: self.onTap) {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                self.selectionMark
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.plan.title)
                        .font(forCategory: .title3)
                        .foregroundStyle(ColorPalette.textPrimary)
                    if self.plan.hasFreeTrial {
                        Text("Try it now for free")
                            .font(forCategory: .caption1)
                            .foregroundStyle(ColorPalette.accent)
                    }
                }
                Spacer(minLength: DS.Spacing.xs)
                VStack(alignment: .trailing, spacing: 2) {
                    if let trialDuration = self.plan.trialDuration {
                        Text(trialDuration)
                            .font(forCategory: .headline)
                            .foregroundStyle(ColorPalette.accent)
                    }
                    Text(self.plan.priceText)
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)
            .frame(minHeight: 68)
            .frame(maxWidth: .infinity)
            .background(self.isSelected ? ColorPalette.accent.opacity(0.12) : ColorPalette.surface,
                        in: .rect(cornerRadius: DS.Radius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                    .strokeBorder(self.isSelected ? ColorPalette.accent : ColorPalette.separator,
                                  lineWidth: self.isSelected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if let savingBadge = self.plan.savingBadge {
                    Text(savingBadge)
                        .font(forCategory: .callout)
                        .foregroundStyle(ColorPalette.background)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 3)
                        .background(ColorPalette.premium, in: .capsule)
                        .offset(x: -DS.Spacing.sm, y: -9)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(DS.Motion.quick, value: self.isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(self.isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var selectionMark: some View {
        ZStack {
            Circle()
                .strokeBorder(self.isSelected ? ColorPalette.accent : ColorPalette.textTertiary,
                              lineWidth: self.isSelected ? 0 : 1.5)
            if self.isSelected {
                Circle().fill(ColorPalette.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ColorPalette.surface)
            }
        }
        .frame(width: 24, height: 24)
    }
}

#Preview("Plan cards") {
    let yearly = SubscriptionPaywallPlan(product: nil,
                                         title: "Yearly",
                                         trialDuration: "7 days",
                                         priceText: "then 1,54 €/week",
                                         savingBadge: "Save 73%",
                                         fullDescriptionText: "Free for 7 days, then 79,99 €/year")
    let weekly = SubscriptionPaywallPlan(product: nil,
                                         title: "Weekly",
                                         trialDuration: "7 days",
                                         priceText: "then 5,99 €/week",
                                         savingBadge: nil,
                                         fullDescriptionText: "Free for 7 days, then 5,99 €/week")
    return VStack(spacing: DS.Spacing.sm) {
        SubscriptionPlanCardView(plan: weekly, isSelected: false, onTap: {})
        SubscriptionPlanCardView(plan: yearly, isSelected: true, onTap: {})
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorPalette.background)
}
