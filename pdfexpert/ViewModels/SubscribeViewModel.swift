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

struct SubscriptionPlan: Hashable {
    let product: Product?
    let descriptionText: String
}

struct SubscriptionPlanDuo {
    let defaultSubscriptionPlan: SubscriptionPlan
    let freeTrialSubscriptionPlan: SubscriptionPlan?
}

extension Container {
    var subscribeViewModel: Factory<SubscribeViewModel> {
        self { SubscribeViewModel() }.singleton
    }
}

class SubscribeViewModel: ObservableObject {
    
    @Published var subscribeParentalCheck: ParentalCheck<SubscriptionPlan>? = nil
    @Published var isPremium: Bool = false
    
    @Published var asyncSubscriptionPlans: AsyncOperation<SubscriptionPlanDuo, RefreshError> = AsyncOperation(status: .empty)
    @Published var restorePurchaseRequest: AsyncOperation<Bool, RestorePurchaseError> = AsyncOperation(status: .empty)
    @Published var purchaseRequest: AsyncOperation<(), PurchaseError> = AsyncOperation(status: .empty)
    
    @Injected(\.store) private var store
    @Injected(\.coordinator) private var coordinator
    
    private var cancelBag = Set<AnyCancellable>()
    
    init() {
        self.store.isPremium.sink { self.onPremiumStateChanged(isPremium: $0) }.store(in: &self.cancelBag)
    }
    
    @MainActor
    func refresh() {
        
        self.asyncSubscriptionPlans = AsyncOperation(status: .loading(0.0))
        
        Task {
            do {
                try await self.store.refreshAll()
                let subscriptionPlansDuo = try await Self.productsToSubscriptionPlanDuo(products: self.store.subscriptions)
                self.asyncSubscriptionPlans = AsyncOperation(status: .data(subscriptionPlansDuo))
            } catch {
                let convertedError = RefreshError.convertError(fromError: error)
                self.asyncSubscriptionPlans = AsyncOperation(status: .error(convertedError))
            }
        }
    }
    
    @MainActor
    func subscribeParentalCheck(subscriptionPlan: SubscriptionPlan) {
        self.subscribeParentalCheck = .checking(subscriptionPlan)
    }
    
    @MainActor
    func subscribe(subscriptionPlan: SubscriptionPlan) {
        
        guard let product = subscriptionPlan.product else {
            self.purchaseRequest = AsyncOperation(status: .error(.unknownError))
            return
        }
        
        self.purchaseRequest = AsyncOperation(status: .loading(0.0))
        
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
            self.restorePurchaseRequest = AsyncOperation(status: .loading(0.0))
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
    
    private static func productsToSubscriptionPlanDuo(products: [Product]) async throws -> SubscriptionPlanDuo {
        let subscriptions = products.filter { $0.subscription != nil }
        
        guard let defaultSubscription = subscriptions.first (where: { $0.subscription?.introductoryOffer == nil }) else {
            throw RefreshError.missingDefaultSubscriptionPlanError
        }
        
        let freeTrialSubscription = subscriptions.first (where: { $0.subscription?.introductoryOffer?.paymentMode == .freeTrial })
        let eligibleForIntroductoryOffer = await freeTrialSubscription?.subscription?.isEligibleForIntroOffer ?? false
        
        let defaultSubscriptionPlan = SubscriptionPlan(product: defaultSubscription,
                                                       descriptionText: defaultSubscription.descriptionText)
        let freeTrialSubscriptionPlan: SubscriptionPlan? = {
            guard let freeTrialSubscription = freeTrialSubscription, eligibleForIntroductoryOffer else {
                return nil
            }
            return SubscriptionPlan(product: freeTrialSubscription,
                               descriptionText: freeTrialSubscription.descriptionText)
        }()
        return SubscriptionPlanDuo(defaultSubscriptionPlan: defaultSubscriptionPlan, freeTrialSubscriptionPlan: freeTrialSubscriptionPlan)
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
