//
//  SubscriptionVerticalViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 13/04/23.
//

import Foundation
import StoreKit
import Combine
import Factory
import Collections

extension Container {
    var subscriptionVerticalViewModel: Factory<SubscriptionVerticalViewModel> {
        self { SubscriptionVerticalViewModel() }.shared
    }
}

struct SubscriptionPlanVerticalItem: SubscriptionPlan {
    let product: Product?
    let titleShort: String
    let descriptionText: String
    let fullDescriptionText: String
    let freeTrialText: String?
    let discountText: String?
}

fileprivate extension Product {
    func getSubscriptionPlanVerticalItem(totalProducts: [Product]) -> SubscriptionPlanVerticalItem {
        return SubscriptionPlanVerticalItem(product: self,
                                titleShort: self.titleShort,
                                descriptionText: self.descriptionText,
                                fullDescriptionText: self.fullDescriptionText,
                                freeTrialText: self.freeTrialText,
                                discountText: self.getDiscountPercentage(forProducts: totalProducts))
    }
}

fileprivate let productMetaViewValueVertical: String = "vertical"

class SubscriptionVerticalViewModel: SubscribeViewModel<SubscriptionPlanVerticalItem> {
    
    @Published var asyncSubscriptionPlanList: AsyncOperation<[SubscriptionPlanVerticalItem], RefreshError> = AsyncOperation(status: .empty) {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    
    @Published var selectedSubscriptionItemIndex: Int = 0 {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    
    @Injected(\.store) private var store
    
    @MainActor
    func refresh() {
        
        self.asyncSubscriptionPlanList = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        Task {
            do {
                try await self.store.refreshAll()
                let subscriptionPlanList = try await self.productsToSubscriptionList(products: self.store.subscriptions)
                if subscriptionPlanList.count > 0 {
                    self.asyncSubscriptionPlanList = AsyncOperation(status: .data(subscriptionPlanList))
                } else {
                    self.asyncSubscriptionPlanList = AsyncOperation(status: .error(.missingExpectedSubscriptionPlanError))
                }
            } catch {
                let convertedError = RefreshError.convertError(fromError: error)
                self.asyncSubscriptionPlanList = AsyncOperation(status: .error(convertedError))
            }
        }
    }
    
    private func productsToSubscriptionList(products: [Product]) async throws -> [SubscriptionPlanVerticalItem] {
        var subscriptions = getSubscriptionsForView(products: products, store: self.store, viewKey: productMetaViewValueVertical)
        
        subscriptions.sort { product1, product2 in
            product1.subscription?.subscriptionPeriod.days ?? 0 > product2.subscription?.subscriptionPeriod.days ?? 0
        }
        
        return subscriptions.map { $0.getSubscriptionPlanVerticalItem(totalProducts: subscriptions) }
    }
    
    private func updateCurrentSubscriptionPlan() {
        guard let subscriptionPlanList = self.asyncSubscriptionPlanList.data,
              self.selectedSubscriptionItemIndex >= 0,
              self.selectedSubscriptionItemIndex < subscriptionPlanList.count else {
            return
        }
        self.currentSubscriptionPlan = subscriptionPlanList[self.selectedSubscriptionItemIndex]
    }
}
