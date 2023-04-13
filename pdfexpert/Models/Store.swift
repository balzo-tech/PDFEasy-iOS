//
//  Store.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 03/03/23.
//

import Foundation
import Factory
import StoreKit
import Combine

protocol Store {
    var subscriptions: [Product] { get }
    var consumables: [Product] { get }
    var purchasedSubscriptions: [Product] { get }
    var subscriptionGroupStatus: RenewalState? { get }
    var isPremium: CurrentValueSubject<Bool, Never> { get }
    
    func refreshAll() async throws
    func requestProducts() async throws
    func purchase(_ product: Product) async throws -> Transaction?
    func isPurchased(_ product: Product) async throws -> Bool
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T
    func updateCustomerProductStatus() async
    func getProductData(forProductId productId: String) -> Any?
    func sortByPrice(_ products: [Product]) -> [Product]
}

extension Container {
    var store: Factory<Store> {
        self { StoreImpl() }.singleton
    }
}
