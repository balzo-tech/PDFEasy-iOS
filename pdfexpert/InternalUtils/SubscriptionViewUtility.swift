//
//  SubscriptionViewUtility.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import StoreKit
import Collections

fileprivate struct InternalSubscriptionPeriod {
    let unit: Product.SubscriptionPeriod.Unit
    let value: Int
}

extension Product.SubscriptionPeriod.Unit {
    var displayUnitSingle: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        default: return ""
        }
    }
    
    var displayUnitPeriod: String {
        switch self {
        case .day: return "daily"
        case .week: return "weekly"
        case .month: return "monthly"
        case .year: return "yearly"
        default: return ""
        }
    }
    
    var displayUnitMultiple: String {
        switch self {
        case .day: return "days"
        case .week: return "weeks"
        case .month: return "months"
        case .year: return "years"
        default: return ""
        }
    }
    
    var displayUnitSingleWithArticle: String {
        switch self {
        case .day: return "a day"
        case .week: return "a week"
        case .month: return "a month"
        case .year: return "an year"
        default: return ""
        }
    }
    
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        default: return 0
        }
    }
    
    var previousUnit: Self? {
        switch self {
        case .day: return nil
        case .week: return .day
        case .month: return .week
        case .year: return .month
        default: return nil
        }
    }
}

fileprivate extension InternalSubscriptionPeriod {
    
    var days: Int {
        return self.unit.days * self.value
    }
    
    // period == 1 ? "a day" : "5 days"
    var displayPeriodStartStatement: String {
        if self.value > 1 {
            return "\(self.value) \(self.unit.displayUnitMultiple)"
        } else {
            return self.unit.displayUnitSingleWithArticle
        }
    }
    
    // period == 1 ? "day" : "5 days"
    var displayPeriod: String {
        if self.value > 1 {
            return "\(self.value) \(self.unit.displayUnitMultiple)"
        } else {
            return self.unit.displayUnitSingle
        }
    }
    
    // period == 1 ? "daily" : "5 days"
    var displayFrequency: String {
        if self.value > 1 {
            return "\(self.value) \(self.unit.displayUnitMultiple)"
        } else {
            return self.unit.displayUnitPeriod
        }
    }
    
    // period == 1 ? "1 day" : "5 days"
    var displayPeriodWithNumber: String {
        "\(self.value) \(self.value > 1 ? self.unit.displayUnitMultiple : self.unit.displayUnitSingle)"
    }
    
    func convert(toUnit unit: Product.SubscriptionPeriod.Unit) -> Self {
        return InternalSubscriptionPeriod(unit: unit, value: self.days/unit.days)
    }
}

extension Product.SubscriptionPeriod {
    
    // 3 days => 3, 3 weeks => 21, 2 months => 60, ...
    // Not reliable for legal information or date calculations,
    // since months and years are fixed on 30 and 365 respectively
    var days: Int {
        return InternalSubscriptionPeriod(unit: self.unit, value: self.value).days
    }
    
    fileprivate func getInternalPeriod(weekFrom7days: Bool) -> InternalSubscriptionPeriod {
        if weekFrom7days, self.value == 7, self.unit == .day {
            return InternalSubscriptionPeriod(unit: .week, value: 1)
        } else {
            return InternalSubscriptionPeriod(unit: self.unit, value: self.value)
        }
    }
}

extension Product {
    
    var title: String {
        var text = "Premium"
        if let subscription = self.subscription {
            text += " \(subscription.subscriptionPeriod.getInternalPeriod(weekFrom7days: true).displayPeriodWithNumber)"
        }
        return text
    }
    
    var titleShort: String {
        var text = ""
        if let subscription = self.subscription {
            text += "\(subscription.subscriptionPeriod.getInternalPeriod(weekFrom7days: true).displayFrequency)"
        }
        text += " \(self.displayPrice)"
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var period: String {
        var text = ""
        if let subscription = self.subscription {
            text += "\(subscription.subscriptionPeriod.getInternalPeriod(weekFrom7days: true).displayFrequency)"
        }
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var priceText: String {
        return self.displayPrice
    }
    
    var descriptionText: String {
        var text = self.getPriceText(weekFrom7days: false, customUnitPeriod: .week)
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var fullDescriptionText: String {
        var text = ""
        if let introductortOffer = self.subscription?.introductoryOffer {
            text += "\(introductortOffer.period.getInternalPeriod(weekFrom7days: false).displayPeriodStartStatement) free, then "
        }
        text += self.getPriceText(weekFrom7days: true)
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var freeTrialText: String? {
        if let introductoryOffer = self.subscription?.introductoryOffer, introductoryOffer.paymentMode == .freeTrial {
            let freeTrialDuration = introductoryOffer.period.getInternalPeriod(weekFrom7days: false).displayPeriodWithNumber
            return "FREE TRIAL for \(freeTrialDuration)"
        } else {
            return nil
        }
    }
    
    // Returned only if:
    // - The current product is a subscription
    // - The current product is the most convenient one
    // - There is another product which is a subscription and is less convenient
    func getBestDiscount(forProducts products: [Product]) -> String? {
        // Compare subscription periods instead of the products themselves to handle cases of identical
        // subscriptions that varies only for introductory offers (e.g.: yearly with free trial, yearly without free trial)
        let mostConvenientSubscriptionPeriod = Self.getMostConvenientSubscription(fromProducts: products)?.subscription?.subscriptionPeriod
        guard let mostConvenientSubscriptionPeriod, self.subscription?.subscriptionPeriod == mostConvenientSubscriptionPeriod else {
            return nil
        }
        guard let discountPercentage = self.getDiscountPercentage(forProducts: products) else {
            return nil
        }
        return "SAVE \(discountPercentage)"
    }
    
    // Returned only if:
    // - The current product is a subscription
    // - There is another product which is a subscription and is less convenient
    func getDiscount(forProducts products: [Product]) -> String? {
        guard let subscription = self.subscription else {
            return nil
        }
        guard let discountPercentage = self.getDiscountPercentage(forProducts: products) else {
            return nil
        }
        guard let previousUnit = subscription.subscriptionPeriod.unit.previousUnit else {
            return nil
        }
        let periodInPreviousUnit = subscription.subscriptionPeriod.getInternalPeriod(weekFrom7days: false).convert(toUnit: previousUnit)
        var text = periodInPreviousUnit.displayPeriodWithNumber
        text += " at "
        text += self.getPriceText(weekFrom7days: false, customUnitPeriod: previousUnit, showTrailing: false)
        text = text.capitalizingFirstLetter()
        text += ", save \(discountPercentage)"
        return text
    }
    
    private func getDiscountPercentage(forProducts products: [Product]) -> String? {
        let nextMostConvenientProduct = Self.getMostConvenientSubscription(fromProducts: products, worseThan: self)
        
        guard let nextMostConvenientProduct = nextMostConvenientProduct else {
            return nil
        }
        guard let priceYearly = self.priceYearly,
              let nextMostConvenientProductPriceYearly = nextMostConvenientProduct.priceYearly else {
            return nil
        }
        
        let discount = Decimal(1) - priceYearly / nextMostConvenientProductPriceYearly
        let discountPercentage = discount.formatted(.percent
            .precision(.integerAndFractionLength(integerLimits: ..<3, fractionLimits: 0...0)))
        return discountPercentage
    }
    
    private static func sortedSubscriptionsBasedOnConvenience(fromProducts products: [Product]) -> [Product] {
        return products.filter { $0.priceYearly != nil }.sorted { $0.priceYearly ?? 0 < $1.priceYearly ?? 0 }
    }
    
    private static func getMostConvenientSubscription(fromProducts products: [Product], worseThan referenceProduct: Product? = nil) -> Product? {
        let sortedProducts = Self.sortedSubscriptionsBasedOnConvenience(fromProducts: products)
        if let referenceProduct = referenceProduct, let index = sortedProducts.firstIndex(of: referenceProduct) {
            let nextProductIndex = index + 1
            if nextProductIndex < sortedProducts.count {
                return sortedProducts[nextProductIndex]
            } else {
                return nil
            }
        } else {
            return sortedProducts.first
        }
    }
    
    private var priceYearly: Decimal? {
        if let subscription = self.subscription {
            return (self.price / Decimal(subscription.subscriptionPeriod.days)) * Decimal(SubscriptionPeriod.Unit.year.days)
        } else {
            return nil
        }
    }
    
    // if customUnitPeriod == nil
    // <price>/<displayPeriod>. E.g.: 99.99€/year, 19.99/2 months
    // otherwise
    // <price in custom unit period>(= (price / period days) * custom unit period days)/<display period of custom unit period>
    // E.g.: custom unit period == week => 89.99€/year => 1.73€/week
    private func getPriceText(weekFrom7days: Bool, customUnitPeriod: SubscriptionPeriod.Unit? = nil, showTrailing: Bool = true) -> String {
        if let subscription = self.subscription {
            var text = ""
            if let customUnitPeriod = customUnitPeriod {
                let pricePerUnit = (self.price / Decimal(subscription.subscriptionPeriod.days)) * Decimal(customUnitPeriod.days)
                text += self.priceFormatStyle
                    .precision(.integerAndFractionLength(integerLimits: 1..<3, fractionLimits: 2...2))
                    .format(pricePerUnit)
                if showTrailing {
                    text += "/\(customUnitPeriod.displayUnitSingle)"
                }
            } else {
                text += self.displayPrice
                if showTrailing {
                    text += "/\(subscription.subscriptionPeriod.getInternalPeriod(weekFrom7days: weekFrom7days).displayPeriod)"
                }
            }
            return text
        } else {
            return self.displayPrice
        }
    }
}

let productMetaViewsKey: String = "views"

func getSubscriptionsForView(products: [Product], store: Store, viewKey: String) -> [Product] {
    return products.filter {
        if $0.subscription != nil,
           let metaDictionary = store.getProductData(forProductId: $0.id) as? [String: Any],
           let views = metaDictionary[productMetaViewsKey] as? [String],
           views.contains(viewKey) {
            return true
        } else {
            return false
        }
    }
}

extension Array where Element == Product {
    func subscriptionPairs<T: SubscriptionPlan>(conversion: ((Product?) -> T?)) async throws -> [SubscriptionPlanCombo<T>] {
        var groupedSubscriptions: OrderedDictionary<Int, [Product]> = self.reduce([:]) { partialResult, subscription in
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
        
        let subscriptionPlanPairs: [SubscriptionPlanCombo<T>] = groupedSubscriptions.reduce([]) { partialResult, rawPair in
            var partialResult = partialResult
            let freeTrialSubscriptionPlan = conversion(rawPair.value.first (where: { $0.subscription?.introductoryOffer?.paymentMode == .freeTrial }))
            let standardSubscriptionPlan = conversion(rawPair.value.first (where: { $0.subscription?.introductoryOffer == nil }))
            if standardSubscriptionPlan != nil || freeTrialSubscriptionPlan != nil {
                partialResult.append(SubscriptionPlanCombo<T>(standardSubscriptionPlan: standardSubscriptionPlan,
                                                              freeTrialSubscriptionPlan: freeTrialSubscriptionPlan))
            }
            return partialResult
        }
        return subscriptionPlanPairs
    }
}
