//
//  SubscriptionViewUtility.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import StoreKit

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
        case .month: return 31
        case .year: return 365
        default: return 0
        }
    }
}

extension Product.SubscriptionPeriod {
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
    
    // period == 1 ? "1 day" : "5 days"
    var displayPeriodWithNumber: String {
        return "\(self.value) \(self.value > 1 ? self.unit.displayUnitMultiple : self.unit.displayUnitSingle)"
    }
    
    // 3 days => 3, 3 weeks => 21, 2 months => 62, ...
    // Not reliable for legal information or date calculations,
    // since months and years are fixed on 31 and 365 respectively
    var days: Int {
        return self.unit.days * self.value
    }
}

extension Product {
    
    var title: String {
        var text = "Premium"
        if let subscription = self.subscription {
            text += " \(subscription.subscriptionPeriod.displayPeriodWithNumber)"
        }
        return text
    }
    
    var titleShort: String {
        var text = ""
        if let subscription = self.subscription {
            text += "\(subscription.subscriptionPeriod.unit.displayUnitPeriod)"
        }
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var descriptionText: String {
        var text = self.getPriceText(withCustomUnitPeriod: .week)
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var fullDescriptionText: String {
        var text = ""
        if let introductortOffer = self.subscription?.introductoryOffer {
            text += "\(introductortOffer.period.displayPeriodStartStatement) free, then "
        }
        text += self.getPriceText()
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var freeTrialText: String? {
        if let introductoryOffer = self.subscription?.introductoryOffer, introductoryOffer.paymentMode == .freeTrial {
            let freeTrialDuration = introductoryOffer.period.displayPeriodWithNumber
            return "FREE TRIAL for \(freeTrialDuration)"
        } else {
            return nil
        }
    }
    
    // Returned only if:
    // - The current product is a subscription
    // - The current product is the most convenient one
    // - There is another product which is a subscription and is less convenient
    func getDiscountPercentage(forProducts products: [Product]) -> String? {
        let mostConvenientProduct = Self.getMostConvenientSubscription(fromProducts: products)
        
        guard let mostConvenientProduct = mostConvenientProduct, mostConvenientProduct == self else {
            return nil
        }
        
        let remainingProducts = products.filter { $0 != mostConvenientProduct }
        let secondMostConvenientProduct = Self.getMostConvenientSubscription(fromProducts: remainingProducts)
        
        guard let secondMostConvenientProduct = secondMostConvenientProduct else {
            return nil
        }
        guard let mostConvenientPriceYearly = mostConvenientProduct.priceYearly,
              let secondMostConvenientPriceYearly = secondMostConvenientProduct.priceYearly else {
            return nil
        }
        
        let discount = Decimal(1) - mostConvenientPriceYearly / secondMostConvenientPriceYearly
        let discountPercentage = discount.formatted(.percent
            .precision(.integerAndFractionLength(integerLimits: ..<3, fractionLimits: 0...0)))
        return "\(discountPercentage) DISCOUNT"
    }
    
    private static func getMostConvenientSubscription(fromProducts products: [Product]) -> Product? {
        var mostConvenientProduct: Product? = nil
        for product in products {
            if let currentProductPriceYearly = product.priceYearly {
                if let mostConvenient = mostConvenientProduct {
                    if let mostConvenientPriceYearly = mostConvenient.priceYearly {
                        if currentProductPriceYearly < mostConvenientPriceYearly {
                            mostConvenientProduct = product
                        }
                    } else {
                        assertionFailure("Unexpectedly missing mostConvenientPriceYearly for existing mostConvenientProduct")
                    }
                } else {
                    mostConvenientProduct = product
                }
            }
        }
        return mostConvenientProduct
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
    private func getPriceText(withCustomUnitPeriod customUnitPeriod: SubscriptionPeriod.Unit? = nil) -> String {
        if let subscription = self.subscription {
            var text = ""
            if let customUnitPeriod = customUnitPeriod {
                let pricePerUnit = (self.price / Decimal(subscription.subscriptionPeriod.days)) * Decimal(customUnitPeriod.days)
                text += self.priceFormatStyle
                    .precision(.integerAndFractionLength(integerLimits: ..<3, fractionLimits: 2...2))
                    .format(pricePerUnit)
                text += "/\(customUnitPeriod.displayUnitSingle)"
            } else {
                text += self.displayPrice
                text += "/\(subscription.subscriptionPeriod.displayPeriod)"
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
