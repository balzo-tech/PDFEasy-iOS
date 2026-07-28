//
//  SubscriptionPaywallViewModel.swift
//  PdfExpert
//
//  The paywall's one view model. It turns the plans on sale into two cards —
//  short period first, long period second — and preselects the one that saves
//  the customer the most, which is also the one the renewal notice speaks about.
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

    @MainActor
    override func refresh() {

        self.asyncSubscriptionPlans = AsyncOperation(status: .loading(.undeterminedProgress))

        Task {
            do {
                try await self.store.refreshAll()
                let plans = self.productsToSubscriptionPlans(products: self.store.subscriptions)
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

    private func productsToSubscriptionPlans(products: [Product]) -> [SubscriptionPaywallPlan] {
        let offered = getOfferedSubscriptions(products: products, store: self.store)
            .sorted { ($0.subscription?.subscriptionPeriod.days ?? 0) < ($1.subscription?.subscriptionPeriod.days ?? 0) }
        return offered.map { $0.getSubscriptionPaywallPlan(comparedTo: offered) }
    }

    /// The plan that saves the most, or the longest one when nothing stands out.
    private static func defaultPlanIndex(forPlans plans: [SubscriptionPaywallPlan]) -> Int {
        if let index = plans.firstIndex(where: { $0.savingBadge != nil }) {
            return index
        }
        return max(0, plans.count - 1)
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
