//
//  SubscriptionPaywallView.swift
//  PdfExpert
//
//  The app's only paywall. It replaced three of them — pairs, vertical and
//  picker — which existed to be A/B tested against each other and, between
//  them, sold five products through a free-trial toggle nobody explained.
//
//  What is left is one screen with one decision on it: a day pass, weekly or
//  yearly. Only the yearly plan opens on a free trial — the shorter two charge
//  today — so the trial is something this screen still has to offer rather than
//  the default on every card. The collage overhead says what is being sold, the
//  cards say what it costs, and the notice above the button answers the
//  objection the yearly plan has to answer — that the renewal will arrive
//  unannounced a year from now.
//
//  Closing it asks one question first. A screen left in silence is a sale lost
//  without a word said, so the close button answers with what the subscription
//  would have given and offers the free trial one last time — once per showing,
//  and only while there is a trial left to offer.
//

import SwiftUI
import Factory

struct SubscriptionPaywallView: View {

    @InjectedObject(\.subscriptionPaywallViewModel) var viewModel

    var onComplete: () -> ()

    /// The exit prompt, and the memory of having asked. Asking twice in the same
    /// showing turns a last offer into a trap the customer has to fight.
    @State private var confirmExit = false
    @State private var askedExit = false

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
        // Radiolive's exit offer, word for word — the same title, the same
        // message and the same two buttons it has carried since its UIKit days.
        // The question lives in the message ("do you want to take advantage of
        // it?"), so Yes and No answer that one question rather than the title:
        // the ambiguity that made 89% of a day's paywalls start a checkout in
        // September came from a title and a message asking opposite things.
        .alert("Really?", isPresented: self.$confirmExit) {
            Button("Yes") {
                self.viewModel.onExit(.accepted)
                // Not from inside this closure. The alert is still coming off
                // screen while it runs, and asking for a purchase underneath a
                // dismissal is the dropped presentation in
                // `swiftui-presentation-traps`.
                DispatchQueue.main.async { self.viewModel.startFreeTrial() }
            }
            Button("No", role: .cancel) {
                self.viewModel.onExit(.declined)
                self.onComplete()
            }
        } message: {
            Text(self.exitOfferMessage)
        }
    }

    /// The offer's wording. With a trial it names its length in days, which is
    /// the version Radiolive ships; without a countable length it falls back to
    /// the same sentence with the number taken out, so the prompt never says
    /// "0 days".
    private var exitOfferMessage: String {
        guard let days = self.viewModel.freeTrialDays else {
            return String(localized: "This special offer with a free trial is only available right now.\nWant to take advantage of it?\n\nIt's free!")
        }
        return String(format: String(localized: "This special offer with a %d-day free trial is only available now.\nDo you want to take advantage of it?\n\nIt's Free!!"), days)
    }

    /// Closing: while a free trial is still on the table and the question has not
    /// been asked yet, ask it. Otherwise the door opens straight away.
    private func leave() {
        if !self.askedExit, self.viewModel.freeTrialPlanIndex != nil {
            self.askedExit = true
            self.confirmExit = true
        } else {
            // Nothing was asked this time: either the question has already been
            // put and answered, or there is no trial left to put it about.
            self.viewModel.onExit(.notShown)
            self.onComplete()
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
                                action: self.leave)
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
            Text(self.viewModel.sellsDayPass
                 ? "Edit, sign, convert and protect your PDFs. Take a day or a week — you pay today, and it is done."
                 : "Edit, sign, convert and protect your PDFs. No limits, on every device.")
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
            // The renewal banner answers the objection the yearly plan raises.
            // Where nothing renews it would be answering a question nobody
            // asked, so the pass explains itself instead.
            if self.viewModel.sellsDayPass {
                self.dayPassNotice
            } else {
                SubscriptionRenewalNoticeView()
            }
            self.getDefaultButton(text: self.buttonTitle,
                                  onButtonPressed: { self.viewModel.subscribe() })
            Text(self.viewModel.currentSubscriptionPlan?.fullDescriptionText ?? "")
                .font(forCategory: .body2)
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

    /// What the pass is, said once and plainly: it is the unusual half of this
    /// paywall, and a customer who thinks they are starting a subscription asks
    /// for the money back.
    private var dayPassNotice: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ColorPalette.premium)
                .accessibilityHidden(true)
            Text("The pass unlocks everything for 24 hours. No subscription, no renewal, nothing to cancel.")
                .font(forCategory: .body3)
                .fontWeight(.semibold)
                .foregroundStyle(ColorPalette.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorPalette.premium.opacity(0.15),
                    in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .strokeBorder(ColorPalette.premium.opacity(0.45), lineWidth: 1)
        }
    }

    /// "Try for free" only when the selected plan actually opens with a trial —
    /// promising one on a plan that charges today is the kind of thing App
    /// Review rejects, and rightly.
    private var buttonTitle: String {
        if self.viewModel.currentSubscriptionPlan?.hasFreeTrial ?? false {
            return String(localized: "Try for free")
        }
        return String(localized: "Continue")
    }
}

#Preview("Paywall") {
    SubscriptionPaywallView(onComplete: {})
}
