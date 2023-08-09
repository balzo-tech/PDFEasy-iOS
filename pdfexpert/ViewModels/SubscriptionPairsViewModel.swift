//
//  SubscriptionPairsViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 13/04/23.
//

import Foundation
import StoreKit
import Combine
import Factory

extension Container {
    var subscribtionPairsViewModel: Factory<SubscriptionPairsViewModel> {
        self { SubscriptionPairsViewModel() }
    }
}

struct SubscriptionPlanPairItem: SubscriptionPlan {
    let product: Product?
    let title: String
    let descriptionText: String
    let fullDescriptionText: String
}

fileprivate extension Product {
    var subscriptionPlanPairItem: SubscriptionPlanPairItem? {
        return SubscriptionPlanPairItem(product: self,
                                            title: self.title,
                                            descriptionText: self.descriptionText,
                                            fullDescriptionText: self.fullDescriptionText)
    }
}

typealias SubscriptionPlanPair = SubscriptionPlanCombo<SubscriptionPlanPairItem>

fileprivate let productMetaViewValuePairs: String = "pairs"

class SubscriptionPairsViewModel: SubscribeViewModel<SubscriptionPlanPairItem> {
    
    @Published var selectedSubscriptionPairIndex: Int = 0 {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    @Published var isFreeTrialEnabled: Bool = false {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    @Published var asyncSubscriptionPlanPairs: AsyncOperation<[SubscriptionPlanPair], RefreshError> = AsyncOperation(status: .empty) {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    
    @Published var currentSubscriptionPlanPair: SubscriptionPlanPair?
    
    @Injected(\.store) private var store
    
    @MainActor
    override func refresh() {
        
        self.asyncSubscriptionPlanPairs = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        Task {
            do {
                try await self.store.refreshAll()
                let subscriptionPlanPairs = try await self.productsToSubscriptionPairs(products: self.store.subscriptions)
                if subscriptionPlanPairs.count > 0 {
                    self.asyncSubscriptionPlanPairs = AsyncOperation(status: .data(subscriptionPlanPairs))
                } else {
                    self.asyncSubscriptionPlanPairs = AsyncOperation(status: .error(.missingExpectedSubscriptionPlanError))
                }
            } catch {
                let convertedError = RefreshError.convertError(fromError: error)
                self.asyncSubscriptionPlanPairs = AsyncOperation(status: .error(convertedError))
            }
        }
    }
    
    private func productsToSubscriptionPairs(products: [Product]) async throws -> [SubscriptionPlanPair] {
        let subscriptionProducts = getSubscriptionsForView(products: products, store: self.store, viewKey: productMetaViewValuePairs)
        return try await subscriptionProducts.subscriptionPairs(conversion: { $0?.subscriptionPlanPairItem })
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
