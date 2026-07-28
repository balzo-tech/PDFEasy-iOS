//
//  Store.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/03/23.
//

import Foundation
import StoreKit
import Combine

@MainActor
protocol Store {
    var subscriptions: [Product] { get }
    var consumables: [Product] { get }
    var purchasedSubscriptions: [Product] { get }
    var subscriptionGroupStatus: RenewalState? { get }
    nonisolated var isPremium: CurrentValueSubject<Bool, Never> { get }
    /// Apple's id for the current subscription, as the proxy asks for it: it is
    /// what the server takes to Apple to ask whether this customer is really a
    /// subscriber, and what the monthly allowance is counted against. Stable
    /// across reinstalls and devices, unlike anything the app could mint.
    nonisolated var originalTransactionId: CurrentValueSubject<String?, Never> { get }

    func refreshAll() async throws
    func requestProducts() async throws
    func purchase(_ product: Product) async throws -> Transaction?
    func isPurchased(_ product: Product) async throws -> Bool
    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T
    func updateCustomerProductStatus() async
    nonisolated func getProductData(forProductId productId: String) -> Any?
    nonisolated func sortByPrice(_ products: [Product]) -> [Product]
}
