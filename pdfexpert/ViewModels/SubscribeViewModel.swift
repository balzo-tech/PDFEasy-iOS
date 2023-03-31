//
//  SubscribeViewModel.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import Foundation
import StoreKit
import Combine
import Factory
import Collections

extension Container {
    var subscribeViewModel: Factory<SubscribeViewModel> {
        self { SubscribeViewModel() }.singleton
    }
}

struct SubscriptionPlan: Hashable {
    let product: Product?
    let title: String
    let descriptionText: String
    let fullDescriptionText: String
}

extension Product {
    var subscriptionPlan: SubscriptionPlan? {
        return SubscriptionPlan(product: self,
                                title: self.title,
                                descriptionText: self.descriptionText,
                                fullDescriptionText: self.fullDescriptionText)
    }
}

struct SubscriptionPlanPair {
    let standardSubscriptionPlan: SubscriptionPlan?
    let freeTrialSubscriptionPlan: SubscriptionPlan?
}


class SubscribeViewModel: ObservableObject {
    
    @Published var isPremium: Bool = false
    @Published var selectedSubscriptionPairIndex: Int = 0 {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    @Published var isFreeTrialEnabled: Bool = false {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    @Published var asyncSubscriptionPlanPairs: AsyncOperation<[SubscriptionPlanPair], RefreshError> = AsyncOperation(status: .empty) {
        didSet { self.updateCurrentSubscriptionPlan() }
    }
    @Published var restorePurchaseRequest: AsyncOperation<Bool, RestorePurchaseError> = AsyncOperation(status: .empty)
    @Published var purchaseRequest: AsyncOperation<(), PurchaseError> = AsyncOperation(status: .empty)
    @Published var currentSubscriptionPlan: SubscriptionPlan?
    
    @Injected(\.store) private var store
    @Injected(\.coordinator) private var coordinator
    
    private var cancelBag = Set<AnyCancellable>()
    
    init() {
        self.store.isPremium.sink { self.onPremiumStateChanged(isPremium: $0) }.store(in: &self.cancelBag)
    }
    
    @MainActor
    func refresh() {
        
        self.asyncSubscriptionPlanPairs = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        Task {
            do {
                try await self.store.refreshAll()
                let subscriptionPlanPairs = try await Self.productsToSubscriptionPairs(products: self.store.subscriptions)
                self.asyncSubscriptionPlanPairs = AsyncOperation(status: .data(subscriptionPlanPairs))
            } catch {
                let convertedError = RefreshError.convertError(fromError: error)
                self.asyncSubscriptionPlanPairs = AsyncOperation(status: .error(convertedError))
            }
        }
    }
    
    @MainActor
    func subscribe() {
        
        guard let product = self.currentSubscriptionPlan?.product else {
            self.purchaseRequest = AsyncOperation(status: .error(.unknownError))
            return
        }
        
        self.purchaseRequest = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
        
        Task {
            do {
                _ = try await self.store.purchase(product)
                self.purchaseRequest = AsyncOperation(status: .data(()))
            } catch let error {
                print("Subscribe Error: " + error.localizedDescription)
                let convertedError = PurchaseError.convertError(fromError: error)
                self.purchaseRequest = AsyncOperation(status: .error(convertedError))
            }
        }
    }
    
    @MainActor
    func restorePurchases() {
        Task {
            self.restorePurchaseRequest = AsyncOperation(status: .loading(Progress(totalUnitCount: 1)))
            //This call displays a system prompt that asks users to authenticate with their App Store credentials.
            //Call this function only in response to an explicit user action, such as tapping a button.
            do {
                let currentIsPremium = self.isPremium
                try await AppStore.sync()
                await self.store.updateCustomerProductStatus()
                self.restorePurchaseRequest = AsyncOperation(status: .data(self.isPremium && self.isPremium != currentIsPremium))
            } catch {
                let convertedError = RestorePurchaseError.convertError(fromError: error)
                self.restorePurchaseRequest = AsyncOperation(status: .error(convertedError))
            }
        }
    }
    
    func close() {
        self.coordinator.dismissMonetizationView()
    }
    
    private func onPremiumStateChanged(isPremium: Bool) {
        self.isPremium = isPremium
        if isPremium {
            self.coordinator.dismissMonetizationView()
        }
    }
    
    private static func productsToSubscriptionPairs(products: [Product]) async throws -> [SubscriptionPlanPair] {
        let subscriptions = products.filter { $0.subscription != nil }
        
        var groupedSubscriptions: OrderedDictionary<Int, [Product]> = subscriptions.reduce([:]) { partialResult, subscription in
            var partialResult = partialResult
            if let subscriptionInfo = subscription.subscription {
                let key = subscriptionInfo.subscriptionPeriod.days
                var subscriptions = partialResult[key] ?? []
                subscriptions.append(subscription)
                partialResult[key] = subscriptions
            }
            return partialResult
        }
        
        groupedSubscriptions.sort { pair1, pair2 in
            pair1.key > pair2.key
        }
        
        let subscriptionPlanPairs: [SubscriptionPlanPair] = groupedSubscriptions.reduce([]) { partialResult, rawPair in
            var partialResult = partialResult
            let freeTrialSubscriptionPlan = rawPair.value.first (where: { $0.subscription?.introductoryOffer?.paymentMode == .freeTrial })?.subscriptionPlan
            let standardSubscriptionPlan = rawPair.value.first (where: { $0.subscription?.introductoryOffer == nil })?.subscriptionPlan
            if standardSubscriptionPlan != nil || freeTrialSubscriptionPlan != nil {
                partialResult.append(SubscriptionPlanPair(standardSubscriptionPlan: standardSubscriptionPlan,
                                                          freeTrialSubscriptionPlan: freeTrialSubscriptionPlan))
            }
            return partialResult
        }
        
        return subscriptionPlanPairs
    }
    
    private func updateCurrentSubscriptionPlan() {
        guard let subscriptionPlanPairs = self.asyncSubscriptionPlanPairs.data,
              self.selectedSubscriptionPairIndex >= 0,
              self.selectedSubscriptionPairIndex < subscriptionPlanPairs.count else {
            return
        }
        let selectedSubscriptionPair = subscriptionPlanPairs[self.selectedSubscriptionPairIndex]
        if self.isFreeTrialEnabled {
            self.currentSubscriptionPlan = selectedSubscriptionPair.freeTrialSubscriptionPlan ?? selectedSubscriptionPair.standardSubscriptionPlan
        } else {
            self.currentSubscriptionPlan = selectedSubscriptionPair.standardSubscriptionPlan ?? selectedSubscriptionPair.freeTrialSubscriptionPlan
        }
    }
}

// MARK: - Errors

enum RefreshError: LocalizedError, UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    case missingDefaultSubscriptionPlanError
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        case .missingDefaultSubscriptionPlanError: return "Internal Error. Please try again later"
        }
    }
}

enum RestorePurchaseError: LocalizedError, UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        }
    }
}

enum PurchaseError: LocalizedError, UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        }
    }
}
