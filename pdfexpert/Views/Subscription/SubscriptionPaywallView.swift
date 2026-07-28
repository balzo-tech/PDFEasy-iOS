//
//  SubscriptionPaywallView.swift
//  PdfExpert
//
//  The app's only paywall. It replaced three of them — pairs, vertical and
//  picker — which existed to be A/B tested against each other and, between
//  them, sold five products through a free-trial toggle nobody explained.
//
//  What is left is one screen with one decision on it: weekly or yearly, both
//  opening on a free trial. The collage overhead says what is being sold, the
//  two cards say what it costs, and the notice above the button answers the
//  objection the yearly plan has to answer — that the renewal will arrive
//  unannounced a year from now.
//

import SwiftUI
import Factory

struct SubscriptionPaywallView: View {

    @InjectedObject(\.subscriptionPaywallViewModel) var viewModel

    var onComplete: () -> ()

    var body: some View {
        VStack(spacing: 0) {
            self.topBar
            self.content
        }
        .background(ColorPalette.background)
        .asyncView(asyncOperation: self.$viewModel.purchaseRequest)
        .asyncView(asyncOperation: self.$viewModel.restorePurchaseRequest)
        .onAppear {
            self.viewModel.onAppear()
        }
        .onChange(of: self.viewModel.isPremium) { _, isPremium in
            if isPremium {
                self.onComplete()
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch self.viewModel.asyncSubscriptionPlans.status {
        case .empty: Spacer()
        case .loading: AnimationType.dots.view
        case .data: self.mainView
        case .error: SubscriptionErrorView(onButtonPressed: { self.viewModel.refresh() })
        }
    }

    private var topBar: some View {
        ZStack {
            Button(action: { self.viewModel.restorePurchases() }) {
                Text("Restore purchases")
                    .underline()
                    .font(forCategory: .linkText)
                    .foregroundStyle(ColorPalette.textSecondary)
            }
            HStack {
                Spacer()
                GlassIconButton(systemImage: "xmark",
                                accessibilityLabel: String(localized: "Close"),
                                tint: ColorPalette.textSecondary,
                                action: self.onComplete)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(height: DS.Size.tapTarget)
    }

    /// The collage takes whatever room the rest of the screen leaves it, which is
    /// why it carries the negative layout priority: on a small phone the cards,
    /// the notice and the button all have to fit, and the one thing that can give
    /// way without losing meaning is the picture.
    private var mainView: some View {
        VStack(spacing: 0) {
            PaywallToolCollageView()
                .frame(maxWidth: .infinity, maxHeight: 300)
                .layoutPriority(-1)
            self.headline
            Spacer(minLength: DS.Spacing.md)
            self.footer
        }
        .readableColumn()
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Unlock every tool")
                .font(forCategory: .largeTitle)
                .foregroundStyle(ColorPalette.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Edit, sign, convert and protect your PDFs. No limits, on every device.")
                .font(forCategory: .body2)
                .foregroundStyle(ColorPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.md)
    }

    private var footer: some View {
        VStack(spacing: DS.Spacing.sm) {
            self.plans
            SubscriptionRenewalNoticeView()
            self.getDefaultButton(text: self.buttonTitle,
                                  onButtonPressed: { self.viewModel.subscribe() })
            Text(self.viewModel.currentSubscriptionPlan?.fullDescriptionText ?? "")
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.xs)
    }

    @ViewBuilder private var plans: some View {
        if let plans = self.viewModel.asyncSubscriptionPlans.data {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(Array(plans.enumerated()), id: \.offset) { index, plan in
                    SubscriptionPlanCardView(plan: plan,
                                             isSelected: self.viewModel.selectedPlanIndex == index,
                                             onTap: { self.viewModel.selectedPlanIndex = index })
                }
            }
        }
    }

    /// "Start free trial" only when the selected plan actually opens with one —
    /// promising a trial on a plan that charges today is the kind of thing App
    /// Review rejects, and rightly.
    private var buttonTitle: String {
        if self.viewModel.currentSubscriptionPlan?.hasFreeTrial ?? false {
            return String(localized: "Start free trial")
        }
        return String(localized: "Continue")
    }
}

#Preview("Paywall") {
    SubscriptionPaywallView(onComplete: {})
}
