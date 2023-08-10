//
//  SubscriptionPickerViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 08/08/23.
//

import Foundation
import StoreKit
import Combine
import Factory

extension Container {
    var subscriptionPickerViewModel: Factory<SubscriptionPickerViewModel> {
        self { SubscriptionPickerViewModel() }
    }
}

struct SubscriptionPlanPickerItem: SubscriptionPlan {
    let product: Product?
    let title: String
    let period: String
    let weeklyPriceAndPeriod: String
    let fullDescriptionText: String
    let priceText: String
    let bestDiscountText: String?
}

fileprivate extension Product {
    func getSubscriptionPlanPickerItem(totalProducts: [Product]) -> SubscriptionPlanPickerItem {
        return SubscriptionPlanPickerItem(
            product: self,
            title: self.title,
            period: self.period,
            weeklyPriceAndPeriod: self.weeklyPriceAndPeriod,
            fullDescriptionText: self.fullDescriptionText,
            priceText: self.priceText,
            bestDiscountText: self.getBestDiscount(forProducts: totalProducts)
        )
    }
}

class SubscriptionPickerViewModel: SubscribeViewModel<SubscriptionPlanPickerItem> {
    
    fileprivate static let productMetaViewValue: String = "picker"
    
    typealias PlanPair = SubscriptionPlanCombo<SubscriptionPlanPickerItem>
    
    @Published var selectedSubscriptionPairIndex: Int = 0 {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    @Published var isFreeTrialEnabled: Bool = false {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    @Published var asyncSubscriptionPlanPairs: AsyncOperation<[PlanPair], RefreshError> = AsyncOperation(status: .empty) {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    
    @Published var currentSubscriptionPlanPair: PlanPair?
    
    var subscriptionPlans: [SubscriptionPlanPickerItem] {
        guard let pairs = self.asyncSubscriptionPlanPairs.data else {
            return []
        }
        let plans = pairs.compactMap { $0.freeTrialSubscriptionPlan ?? $0.standardSubscriptionPlan }
        guard plans.count == pairs.count else {
            return []
        }
        return plans
    }
    
    @Injected(\.store) private var store
    
    @MainActor
    override func refresh() {
        
        self.asyncSubscriptionPlanPairs = .init(status: .loading(.undeterminedProgress))
        
        Task {
            do {
                try await self.store.refreshAll()
                let subscriptionPlanPairs = try await self.productsToSubscriptionPairs(products: self.store.subscriptions)
                if subscriptionPlanPairs.count > 0 {
                    self.asyncSubscriptionPlanPairs = .init(status: .data(subscriptionPlanPairs))
                } else {
                    self.asyncSubscriptionPlanPairs = .init(status: .error(.missingExpectedSubscriptionPlanError))
                }
            } catch {
                let convertedError = RefreshError.convertError(fromError: error)
                self.asyncSubscriptionPlanPairs = AsyncOperation(status: .error(convertedError))
            }
        }
    }
    
    private func productsToSubscriptionPairs(products: [Product]) async throws -> [PlanPair] {
        let subscriptionProducts = getSubscriptionsForView(products: products, store: self.store, viewKey: Self.productMetaViewValue)
        return try await subscriptionProducts.subscriptionPairs(periodOrderDesc: false, conversion: { $0?.getSubscriptionPlanPickerItem(totalProducts: products) })
    }
    
    private func updateCurrentSubscriptionPlan() {
        guard let subscriptionPlanPairs = self.asyncSubscriptionPlanPairs.data,
              self.selectedSubscriptionPairIndex >= 0,
              self.selectedSubscriptionPairIndex < subscriptionPlanPairs.count else {
            return
        }
        let currentSubscriptionPlanPair = subscriptionPlanPairs[self.selectedSubscriptionPairIndex]
        if self.isFreeTrialEnabled {
            self.currentSubscriptionPlan = currentSubscriptionPlanPair.freeTrialSubscriptionPlan ?? currentSubscriptionPlanPair.standardSubscriptionPlan
        } else {
            self.currentSubscriptionPlan = currentSubscriptionPlanPair.standardSubscriptionPlan ?? currentSubscriptionPlanPair.freeTrialSubscriptionPlan
        }
        self.currentSubscriptionPlanPair = currentSubscriptionPlanPair
    }
}
