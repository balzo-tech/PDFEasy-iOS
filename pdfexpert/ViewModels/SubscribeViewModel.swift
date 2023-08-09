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

protocol SubscriptionPlan: Hashable {
    var product: Product? { get }
}

struct SubscriptionPlanCombo<T: SubscriptionPlan> {
    let standardSubscriptionPlan: T?
    let freeTrialSubscriptionPlan: T?
    
    func getPlan(forFreeTrialState freeTrialState: Bool) -> T? {
        return freeTrialState ? self.freeTrialSubscriptionPlan : self.standardSubscriptionPlan
    }
}

class SubscribeViewModel<S: SubscriptionPlan>: ObservableObject {
    
    @Published var isPremium: Bool = false
    @Published var restorePurchaseRequest: AsyncOperation<Bool, SharedUnderlyingError> = AsyncOperation(status: .empty)
    @Published var purchaseRequest: AsyncOperation<(), SharedUnderlyingError> = AsyncOperation(status: .empty)
    
    @Published var currentSubscriptionPlan: S?
    
    @Injected(\.store) private var store
    @Injected(\.analyticsManager) private var analyticsManager
    
    private var cancelBag = Set<AnyCancellable>()
    
    init() {
        self.store.isPremium.sink { self.onPremiumStateChanged(isPremium: $0) }.store(in: &self.cancelBag)
    }
    
    @MainActor
    open func refresh() {}
    
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
                let convertedError = SharedUnderlyingError.convertError(fromError: error)
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
                let convertedError = SharedUnderlyingError.convertError(fromError: error)
                self.restorePurchaseRequest = AsyncOperation(status: .error(convertedError))
            }
        }
    }
    
    @MainActor
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.subscription))
        self.refresh()
    }
    
    private func onPremiumStateChanged(isPremium: Bool) {
        self.isPremium = isPremium
    }
}

// MARK: - Errors

enum RefreshError: LocalizedError, UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    case missingExpectedSubscriptionPlanError
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return "Internal Error. Please try again later"
        case .underlyingError(let errorMessage): return errorMessage
        case .missingExpectedSubscriptionPlanError: return "Internal Error. Please try again later"
        }
    }
}
