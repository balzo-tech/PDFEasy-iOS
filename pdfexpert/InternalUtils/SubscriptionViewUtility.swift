//
//  SubscriptionViewUtility.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 24/02/23.
//

import Foundation
import StoreKit

extension Product.SubscriptionPeriod {
    var displayValueSingle: String {
        switch self.unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        default: return ""
        }
    }
    var displayValueMultiple: String {
        switch self.unit {
        case .day: return "days"
        case .week: return "weeks"
        case .month: return "months"
        case .year: return "years"
        default: return ""
        }
    }
    var displayDuration: String {
        if self.value > 1 {
            return "\(self.value) \(self.displayValueMultiple)"
        } else {
            switch self.unit {
            case .day: return "a day"
            case .week: return "a week"
            case .month: return "a month"
            case .year: return "an year"
            default: return ""
            }
        }
    }
    
    var displayPeriod: String {
        if self.value > 1 {
            if self.value == 7, self.unit == .day {
                return "week"
            } else {
                return "\(self.value) \(self.displayValueMultiple)"
            }
        } else {
            return self.displayValueSingle
        }
    }
}

extension Product {
    var descriptionText: String {
        var text = ""
        if let introductortOffer = self.subscription?.introductoryOffer {
            text += "\(introductortOffer.period.displayDuration) free, then "
        }
        text += self.displayPrice
        if let subscription = self.subscription {
            text += "/\(subscription.subscriptionPeriod.displayPeriod)"
        }
        text = text.capitalizingFirstLetter()
        return text
    }
}
