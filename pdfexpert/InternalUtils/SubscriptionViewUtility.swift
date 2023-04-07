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
    var displayPeriodStartStatement: String {
        if self.value > 1 {
            return "\(self.value) \(self.unit.displayUnitMultiple)"
        } else {
            return self.unit.displayUnitSingleWithArticle
        }
    }
    
    var displayPeriod: String {
        if self.value > 1 {
            return "\(self.value) \(self.unit.displayUnitMultiple)"
        } else {
            return self.unit.displayUnitSingle
        }
    }
    
    var displayPeriodWithNumber: String {
        return "\(self.value) \(self.value > 1 ? self.unit.displayUnitMultiple : self.unit.displayUnitSingle)"
    }
    
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
    
    var descriptionText: String {
        var text = self.getPriceText()
//        var text = self.getPriceText(withCustomUnitPeriod: .week)
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var fullDescriptionText: String {
        var text = ""
        if let introductortOffer = self.subscription?.introductoryOffer {
            text += "\(introductortOffer.period.displayPeriodStartStatement) free, then "
        }
        text += self.getPriceText()
//        text += self.getPriceText(withCustomUnitPeriod: .week)
        text = text.capitalizingFirstLetter()
        return text
    }
    
    func getPriceText(withCustomUnitPeriod customUnitPeriod: SubscriptionPeriod.Unit? = nil) -> String {
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
