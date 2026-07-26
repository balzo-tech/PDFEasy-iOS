/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The store class is responsible for requesting products from the App Store and starting purchases.
*/

import Foundation
import StoreKit
import Combine
import Factory

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

//Define our app's subscription tiers by level of service, in ascending order.
public enum SubscriptionTier: Int, Comparable {
    case none = 0
    case standard = 1

    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

extension Container {
    var store: Factory<Store> {
        self { StoreImpl() }.singleton
    }
}

@MainActor
final class StoreImpl: Store {

    private(set) var subscriptions: [Product]
    private(set) var consumables: [Product]

    private(set) var purchasedSubscriptions: [Product] = []
    private(set) var subscriptionGroupStatus: RenewalState?

    nonisolated let isPremium: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)

    // Touched only from the nonisolated init / deinit, never on the main actor.
    nonisolated(unsafe) var updateListenerTask: Task<Void, Error>? = nil

    private let productIdToProduct: [String: Any]

    @Injected(\.analyticsManager) var analyticsManager

    nonisolated init() {
        self.productIdToProduct = Self.loadProductIdToProductData().reduce([:], {
            var result = $0
            result[(Bundle.main.bundleIdentifier ?? "") + "." + $1.key] = $1.value
            return result
        })

        //Initialize empty products, and then do a product request asynchronously to fill them in.
        self.subscriptions = []
        self.consumables = []

        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        self.updateListenerTask = self.listenForTransactions()

        #if DEBUG
        // Sent here as well as honoured in subscriptionStatusToIsPremium, because
        // the refresh below can throw before it ever gets to publish a status.
        if Self.isDebugPremiumForced {
            self.isPremium.send(true)
        }
        #endif

        Task {
            try await self.refreshAll()
//            //During store initialization, request products from the App Store.
//            try await requestProducts()
//
//            //Deliver products that the customer purchases.
//            await updateCustomerProductStatus()
        }
    }

    deinit {
        self.updateListenerTask?.cancel()
    }
    
    nonisolated static func loadProductIdToProductData() -> [String: Any] {
        guard let path = Bundle.main.path(forResource: "Products", ofType: "plist"),
              let plist = FileManager.default.contents(atPath: path),
              let data = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any] else {
            return [:]
        }
        return data
    }

    nonisolated func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    //Deliver products to the user.
                    await self.updateCustomerProductStatus()

                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    func refreshAll() async throws {
        
        //During store initialization, request products from the App Store.
        try await self.requestProducts()

        //Deliver products that the customer purchases.
        await self.updateCustomerProductStatus()
    }

    @MainActor
    func requestProducts() async throws {
        do {
            //Request products from the App Store using the identifiers that the Products.plist file defines.
            let storeProducts = try await Product.products(for: self.productIdToProduct.keys)
            
            var newSubscriptions: [Product] = []
            var newConsumables: [Product] = []

            //Filter the products into categories based on their type.
            for product in storeProducts {
                switch product.type {
                case .consumable:
                    newConsumables.append(product)
                case .nonConsumable:
                    debugPrint("Unexpected non consumable found")
                case .autoRenewable:
                    newSubscriptions.append(product)
                case .nonRenewable:
                    debugPrint("Unexpected non renewable found")
                default:
                    //Ignore this product.
                    print("Unknown product")
                }
            }

            //Sort each product category by price, lowest to highest, to update the store.
            self.consumables = self.sortByPrice(newConsumables)
            self.subscriptions = self.sortByPrice(newSubscriptions)
        } catch {
            print("Failed product request from the App Store server: \(error)")
            throw error
        }
    }

    @MainActor
    func purchase(_ product: Product) async throws -> Transaction? {
        //Begin purchasing the `Product` the user selects.
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            //Check whether the transaction is verified. If it isn't,
            //this function rethrows the verification error.
            let transaction = try self.checkVerified(verification)

            //The transaction is verified. Deliver content to the user.
            await self.updateCustomerProductStatus()

            //Always finish a transaction.
            await transaction.finish()
            
            // Sent custom method to analytics because free trials are not always automatically tracked
            // (e.g.: Firebase)
            self.analyticsManager.track(event: .checkoutCompleted(subscriptionPlanProduct: product))

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    func isPurchased(_ product: Product) async throws -> Bool {
        //Determine whether the user purchases a given product.
        switch product.type {
        case .nonRenewable:
            debugPrint("Unexpected non renewable found")
            return false
        case .nonConsumable:
            debugPrint("Unexpected non consumable found")
            return false
        case .autoRenewable:
            return self.purchasedSubscriptions.contains(product)
        default:
            return false
        }
    }

    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }

    @MainActor
    func updateCustomerProductStatus() async {
        var purchasedSubscriptions: [Product] = []

        //Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try self.checkVerified(result)

                //Check the `productType` of the transaction and get the corresponding product from the store.
                switch transaction.productType {
                case .nonConsumable:
                    debugPrint("Unexpected non consumable found")
                case .nonRenewable:
                    debugPrint("Unexpected non renewable found")
                case .autoRenewable:
                    if let subscription = self.subscriptions.first(where: { $0.id == transaction.productID }) {
                        purchasedSubscriptions.append(subscription)
                    }
                default:
                    break
                }
            } catch {
                print()
            }
        }

        //Update the store information with auto-renewable subscription products.
        self.purchasedSubscriptions = purchasedSubscriptions

        //Check the `subscriptionGroupStatus` to learn the auto-renewable subscription state to determine whether the customer
        //is new (never subscribed), active, or inactive (expired subscription). This app has only one subscription
        //group, so products in the subscriptions array all belong to the same group. The statuses that
        //`product.subscription.status` returns apply to the entire subscription group.
        //With Family Sharing (or otherwise multiple statuses) the group can report
        //several statuses and `.first` may be a non-entitling one, so prefer the status
        //that actually grants access and fall back to the first one.
        let groupStatuses = try? await self.subscriptions.first?.subscription?.status
        let entitlingStatus = groupStatuses?.first(where: {
            Self.subscriptionStatusToIsPremium(subscriptionStatus: $0.state)
        })
        self.subscriptionGroupStatus = (entitlingStatus ?? groupStatuses?.first)?.state

        self.isPremium.send(Self.subscriptionStatusToIsPremium(subscriptionStatus: self.subscriptionGroupStatus))
    }

    nonisolated func getProductData(forProductId productId: String) -> Any? {
        return self.productIdToProduct[productId]
    }

    nonisolated func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { return $0.price < $1.price })
    }

    #if DEBUG
    /// debugPremium=YES makes the app behave as if subscribed, so the premium tool
    /// sheets can be inspected on a simulator — nothing can be bought there, and
    /// the paywall otherwise stands in front of every one of them:
    ///   xcrun simctl spawn booted defaults write <bundle-id> debugPremium -bool YES
    nonisolated static var isDebugPremiumForced: Bool {
        UserDefaults.standard.bool(forKey: "debugPremium")
    }
    #endif

    nonisolated private static func subscriptionStatusToIsPremium(subscriptionStatus: RenewalState?) -> Bool {
        #if DEBUG
        if Self.isDebugPremiumForced { return true }
        #endif
        guard let state = subscriptionStatus else {
            return false
        }
        
        switch state {
        case .subscribed: return true
        case .expired: return false
        case .inBillingRetryPeriod: return true
        case .inGracePeriod: return true
        case .revoked: return false
        default:
            debugPrint("Unhandled RenewalState")
            return false
        }
    }
}

//fileprivate extension String {
//    func removeEnvironmentSuffix() -> String {
//        #if STAGING
//        self.replacingOccurrences(of: ".staging", with: "")
//        #else
//        self
//        #endif
//    }
//}
