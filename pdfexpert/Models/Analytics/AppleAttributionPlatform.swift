//
//  AppleAttributionPlatform.swift
//  PdfExpert
//
//  Apple Search Ads attribution, in the shape every analytics platform here has:
//  one class, one `track`, registered in `AnalyticsManagerImpl`. It takes the
//  place Branch used to hold, and answers a narrower question than Firebase
//  does — which campaign and keyword produced this install, and what it earned.
//
//  So it forwards only the purchases. The SDK's event set is closed (signup,
//  login, trialStarted, subscribed, renewed, purchase): the app has no account
//  to sign up for, and renewals happen with the app closed, which is what the
//  install id travelling as the purchase's `appAccountToken` is for — see
//  `StoreImpl.purchase`. Everything else stays a Firebase-only event.
//

import Foundation
import StoreKit
import AppleAttribution

class AppleAttributionPlatform: AnalyticsPlatform {

    func track(event: AnalyticsEvent) {
        guard case .checkoutCompleted(let product) = event else { return }

        let productId = product.id
        let revenue = product.price
        let currency = product.priceFormatStyle.currencyCode

        guard let subscription = product.subscription else {
            // Not a subscription: the consumables are one-off purchases.
            AppleAttribution.track(.purchase(revenue: revenue, currency: currency, productId: productId))
            return
        }

        // A trial reports no revenue: the money arrives if it converts, and that
        // happens on Apple's side, days later, with the app closed.
        //
        // The period is spelled out in each branch rather than passed as a value
        // because the SDK's plan type cannot be named in this module: the app has
        // a `SubscriptionPlan` protocol of its own that wins the lookup, and the
        // SDK's module name is shadowed by its own facade enum, so qualifying it
        // does not resolve either. Everything is built by inference instead —
        // `.init` from the event case, the period from `.init`.
        let hadTrial = product.isFreeTrial
        switch Self.period(for: subscription.subscriptionPeriod) {
        case .weekly:
            AppleAttribution.track(hadTrial
                ? .trialStarted(plan: .init(period: .weekly, hadTrial: true, productId: productId))
                : .subscribed(plan: .init(period: .weekly, hadTrial: false, productId: productId),
                              revenue: revenue, currency: currency))
        case .monthly:
            AppleAttribution.track(hadTrial
                ? .trialStarted(plan: .init(period: .monthly, hadTrial: true, productId: productId))
                : .subscribed(plan: .init(period: .monthly, hadTrial: false, productId: productId),
                              revenue: revenue, currency: currency))
        case .annual:
            AppleAttribution.track(hadTrial
                ? .trialStarted(plan: .init(period: .annual, hadTrial: true, productId: productId))
                : .subscribed(plan: .init(period: .annual, hadTrial: false, productId: productId),
                              revenue: revenue, currency: currency))
        }
    }

    // MARK: - Private Methods

    /// The SDK's three period buckets, mirrored here so the mapping can be
    /// tested and named without reaching for a type this module cannot spell.
    enum Period {
        case weekly, monthly, annual
    }

    static func period(for period: Product.SubscriptionPeriod) -> Period {
        Self.period(unit: period.unit, value: period.value)
    }

    /// StoreKit describes a period as a unit and a count; the SDK takes three
    /// buckets. A seven-day period is a week, twelve months are a year.
    ///
    /// Takes the two parts rather than the `SubscriptionPeriod` they came from,
    /// because that type cannot be built outside StoreKit and this mapping is
    /// worth a test.
    static func period(unit: Product.SubscriptionPeriod.Unit, value: Int) -> Period {
        switch unit {
        case .day: return value >= 365 ? .annual : (value >= 28 ? .monthly : .weekly)
        case .week: return value >= 52 ? .annual : (value >= 4 ? .monthly : .weekly)
        case .month: return value >= 12 ? .annual : .monthly
        case .year: return .annual
        @unknown default: return .monthly
        }
    }
}
