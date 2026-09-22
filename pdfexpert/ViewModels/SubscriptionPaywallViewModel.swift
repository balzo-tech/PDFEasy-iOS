//
//  SubscriptionPaywallViewModel.swift
//  PdfExpert
//
//  The paywall's one view model. It turns the plans on sale into one card each —
//  shortest period first, longest last — and preselects the one that saves the
//  customer the most, which is also the one the renewal notice speaks about.
//
//  How many cards there are is decided by `Products.plist` (`offered`), not
//  here: it was two for a long time, and is three since the monthly plan came
//  back. Nothing in this file or in the view caps the count.
//
//  The same flag decides which cards promise a free trial, because every plan
//  exists in App Store Connect twice — with an introductory offer and without —
//  and `offered` picks the variant on sale. Since 1.30 only the yearly plan is
//  sold in its trial variant; the weekly and monthly ones charge on the spot.
//
//  One set of storefronts sees something else entirely: a week or a day, both
//  charged on the spot, and no year and no trial. Which ones is `day_pass_
//  storefronts` in Firebase, and the reason is measured — in those markets the
//  free trial is taken and never converts, while the only money that has ever
//  arrived came from small amounts paid immediately. See `K.DayPass`.
//

import Foundation
import StoreKit
import Combine
import Factory

extension Container {
    var subscriptionPaywallViewModel: Factory<SubscriptionPaywallViewModel> {
        self { SubscriptionPaywallViewModel() }
    }
}

struct SubscriptionPaywallPlan: SubscriptionPlan {

    let product: Product?
    /// "Weekly", "Yearly".
    let title: String
    /// "7 days" when the plan opens with a free trial.
    let trialDuration: String?
    /// Always per week — "then 1,54 €/week" on the yearly plan as much as on the
    /// weekly one. Two prices in different units are not a comparison, and the
    /// yearly plan's real charge is spelled out under the button.
    let priceText: String
    /// "Save 73%", on the cheaper plan only.
    let savingBadge: String?
    /// "Free for 7 days, then 79,99 €/year" — the small print under the button.
    let fullDescriptionText: String

    var hasFreeTrial: Bool { self.trialDuration != nil }
}

fileprivate extension Product {
    func getSubscriptionPaywallPlan(comparedTo products: [Product]) -> SubscriptionPaywallPlan {
        // The weekly restatement where there is one, the plan's own price where
        // the plan is already weekly.
        let price = self.weeklyEquivalentPriceText ?? self.recurringPriceText
        return SubscriptionPaywallPlan(
            product: self,
            title: self.planTitle,
            trialDuration: self.freeTrialDuration,
            priceText: self.freeTrialDuration != nil ? String(localized: "then \(price)") : price,
            savingBadge: self.savingBadge(comparedTo: products),
            fullDescriptionText: self.fullDescriptionText
        )
    }
}

class SubscriptionPaywallViewModel: SubscribeViewModel<SubscriptionPaywallPlan> {

    @Published var asyncSubscriptionPlans: AsyncOperation<[SubscriptionPaywallPlan], RefreshError> = AsyncOperation(status: .empty)

    @Published var selectedPlanIndex: Int = 0 {
        didSet { self.updateCurrentSubscriptionPlan() }
    }

    @Injected(\.store) private var store
    @Injected(\.marketProfile) private var marketProfile

    /// True on the paywall that sells a week and a day. The banner about the
    /// yearly renewal has nothing to say there, and the view reads this rather
    /// than guessing from the number of cards.
    @Published private(set) var sellsDayPass: Bool = false

    @MainActor
    override func refresh() {

        self.asyncSubscriptionPlans = AsyncOperation(status: .loading(.undeterminedProgress))

        Task {
            do {
                try await self.store.refreshAll()
                // The storefront, not the locale and not the IP: it is the
                // country whose App Store will take the money, which is the only
                // one that decides what may be sold and at what price. Asked
                // again here rather than trusted from launch, because it changes
                // when the customer changes their Apple Account.
                await self.marketProfile.refresh()
                let plans = self.plans()
                if plans.isEmpty {
                    self.asyncSubscriptionPlans = AsyncOperation(status: .error(.missingExpectedSubscriptionPlanError))
                } else {
                    self.asyncSubscriptionPlans = AsyncOperation(status: .data(plans))
                    self.selectedPlanIndex = Self.defaultPlanIndex(forPlans: plans)
                    self.updateCurrentSubscriptionPlan()
                }
            } catch {
                let convertedError = RefreshError.convertError(fromError: error)
                self.asyncSubscriptionPlans = AsyncOperation(status: .error(convertedError))
            }
        }
    }

    /// The cards this storefront is shown.
    ///
    /// Everywhere else that is every plan `Products.plist` offers, shortest
    /// first. In a day-pass storefront it is two: the pass, then the weekly
    /// plan — a day and a week, both paid today.
    ///
    /// If the consumable has not loaded, the ordinary paywall is shown instead.
    /// A screen offering one subscription and nothing to compare it with sells
    /// less than the one we already have, and a product can fail to arrive for
    /// reasons that have nothing to do with this decision — review state, a
    /// dropped request, a territory it was never released in.
    @MainActor
    private func plans() -> [SubscriptionPaywallPlan] {
        let offered = getOfferedSubscriptions(products: self.store.subscriptions, store: self.store)
            .sorted { ($0.subscription?.subscriptionPeriod.days ?? 0) < ($1.subscription?.subscriptionPeriod.days ?? 0) }

        if self.marketProfile.sellsDayPass,
           // One consumable exists, and it is the pass.
           let pass = self.store.consumables.first,
           let weekly = offered.first(where: { Self.isWeekly($0) }) {
            self.sellsDayPass = true
            return [Self.dayPassPlan(product: pass),
                    weekly.getSubscriptionPaywallPlan(comparedTo: [])]
        }

        self.sellsDayPass = false
        return offered.map { $0.getSubscriptionPaywallPlan(comparedTo: offered) }
    }

    private static func isWeekly(_ product: Product) -> Bool {
        guard let period = product.subscription?.subscriptionPeriod.normalized else { return false }
        return period.unit == .week && period.value == 1
    }

    /// The pass's card. Nothing on it comes from `SubscriptionViewUtility`: a
    /// consumable has no period, so there is no name to derive, no price to
    /// restate per week and no renewal to describe — only what it costs and
    /// what it buys.
    private static func dayPassPlan(product: Product) -> SubscriptionPaywallPlan {
        SubscriptionPaywallPlan(
            product: product,
            title: String(localized: "24-hour pass"),
            trialDuration: nil,
            priceText: product.displayPrice,
            savingBadge: nil,
            fullDescriptionText: String(localized: "\(product.displayPrice) once. Not a subscription: nothing renews."))
    }

    /// The plan that saves the most, or the longest one when nothing stands out
    /// — which on the day-pass paywall is the week rather than the day, and is
    /// meant to be: the pass is the way in for someone who will not subscribe,
    /// not the offer to lead with.
    private static func defaultPlanIndex(forPlans plans: [SubscriptionPaywallPlan]) -> Int {
        if let index = plans.firstIndex(where: { $0.savingBadge != nil }) {
            return index
        }
        return max(0, plans.count - 1)
    }

    /// The plan the exit prompt sells: the only one that opens on a free trial.
    /// Since 1.30 that is the yearly plan, but the view asks the question rather
    /// than assuming it, so `Products.plist` stays the one place that decides.
    var freeTrialPlanIndex: Int? {
        self.asyncSubscriptionPlans.data?.firstIndex { $0.hasFreeTrial }
    }

    /// How long that trial lasts, in days, for the exit prompt's copy: the
    /// offer names the length rather than calling it "free", and the length is
    /// whatever App Store Connect is selling today — three days since
    /// 19 September, seven before that.
    var freeTrialDays: Int? {
        guard let index = self.freeTrialPlanIndex,
              let plan = self.asyncSubscriptionPlans.data?[index] else {
            return nil
        }
        return plan.product?.freeTrialDays
    }

    /// The "Yes" of the exit prompt: select the plan with the trial and buy it,
    /// in that order, so the card the customer sees behind the alert is the one
    /// Apple is about to charge for.
    @MainActor
    func startFreeTrial() {
        guard let index = self.freeTrialPlanIndex else { return }
        self.selectedPlanIndex = index
        self.subscribe()
    }

    private func updateCurrentSubscriptionPlan() {
        guard let plans = self.asyncSubscriptionPlans.data,
              self.selectedPlanIndex >= 0,
              self.selectedPlanIndex < plans.count else {
            return
        }
        self.currentSubscriptionPlan = plans[self.selectedPlanIndex]
    }
}
