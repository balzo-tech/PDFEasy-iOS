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
    var displayDuration: String {
        if self.value > 1 {
            return "\(self.value) \(self.unit.displayUnitMultiple)"
        } else {
            return self.unit.displayUnitSingleWithArticle
        }
    }
    
    var displayPeriod: String {
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
            text += " \(subscription.subscriptionPeriod.displayPeriod)"
        }
        return text
    }
    
    var descriptionText: String {
        var text = self.getPriceText(forUnitPeriod: .week)
        text = text.capitalizingFirstLetter()
        return text
    }
    
    var fullDescriptionText: String {
        var text = ""
        if let introductortOffer = self.subscription?.introductoryOffer {
            text += "\(introductortOffer.period.displayDuration) free, then "
        }
        text += self.getPriceText(forUnitPeriod: .week)
        text = text.capitalizingFirstLetter()
        return text
    }
    
    func getPriceText(forUnitPeriod unitPeriod: SubscriptionPeriod.Unit) -> String {
        if let subscription = subscription {
            let pricePerUnit = (self.price / Decimal(subscription.subscriptionPeriod.days)) * Decimal(unitPeriod.days)
            let text = self.priceFormatStyle
                .precision(.integerAndFractionLength(integerLimits: ..<3, fractionLimits: 2...2))
                .format(pricePerUnit)
            return text + "/\(unitPeriod.displayUnitSingle)"
        } else {
            return self.displayPrice
        }
    }
}
