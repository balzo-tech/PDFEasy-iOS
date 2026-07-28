//
//  SubscriptionViewUtility.swift
//  PdfExpert
//
//  Everything the paywall needs to read out of a StoreKit product: the plan's
//  name, the length of its free trial, the price it renews at, and how much
//  cheaper it is than the other plan on the screen.
//
//  All of it localized. This used to build its strings in English by hand
//  ("Weekly", "Free for 7 days, then …") and show them untouched to an Italian
//  or Spanish customer — on the one screen where a word the reader has to guess
//  at costs a sale.
//

import Foundation
import StoreKit

extension Product.SubscriptionPeriod.Unit {

    /// Rough length in days. Months and years are fixed at 30 and 365, which is
    /// close enough to compare two plans and to restate a yearly price per week,
    /// and nowhere near good enough for a legal statement or a real date.
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        default: return 0
        }
    }
}

extension Product.SubscriptionPeriod {

    var days: Int { self.unit.days * self.value }

    /// Seven days and one week are the same plan, and StoreKit hands back
    /// whichever of the two the product was created with in App Store Connect.
    /// Everything the card says — its name, "9,99 €/week" — has to see one of
    /// them, or a weekly plan ends up titled with its display name and priced
    /// "9,99 €/1 week".
    var normalized: (unit: Unit, value: Int) {
        if self.unit == .day, self.value == 7 { return (.week, 1) }
        return (self.unit, self.value)
    }

    /// "7 days", "1 week", "1 anno" — the system's own wording, in the reader's
    /// language, so no plural rule has to be maintained here.
    var localizedDuration: String {
        var components = DateComponents()
        switch self.unit {
        case .day: components.day = self.value
        case .week: components.weekOfMonth = self.value
        case .month: components.month = self.value
        case .year: components.year = self.value
        default: components.day = self.days
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        formatter.maximumUnitCount = 1
        return formatter.string(from: components) ?? ""
    }
}

extension Product {

    /// The plan's name on its card: "Weekly", "Yearly". Anything that is not a
    /// plain one-unit period (a two-month plan, say) falls back to the name set
    /// in App Store Connect rather than inventing a phrase for it.
    var planTitle: String {
        guard let period = self.subscription?.subscriptionPeriod.normalized, period.value == 1 else {
            return self.displayName
        }
        switch period.unit {
        case .day: return String(localized: "Daily")
        case .week: return String(localized: "Weekly")
        case .month: return String(localized: "Monthly")
        case .year: return String(localized: "Yearly")
        default: return self.displayName
        }
    }

    /// "7 days" when the plan opens with a free trial, nil when it does not.
    var freeTrialDuration: String? {
        guard let offer = self.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else {
            return nil
        }
        // An offer can repeat its period (2 × 1 week); collapse that into a
        // single span so the card reads "14 days" rather than "1 week" twice.
        guard offer.periodCount > 1 else { return offer.period.localizedDuration }
        let totalDays = offer.period.days * offer.periodCount
        var components = DateComponents()
        components.day = totalDays
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day]
        return formatter.string(from: components) ?? offer.period.localizedDuration
    }

    /// "9,99 €/week" — what the plan charges once any trial is over.
    var recurringPriceText: String {
        guard let period = self.subscription?.subscriptionPeriod else { return self.displayPrice }
        return Self.priceText(price: self.displayPrice, period: period)
    }

    /// The same price restated per week — "1,54 €/week" for a yearly plan — so
    /// the two cards can be compared without doing the division in your head.
    /// Nil on a plan that is already weekly, where it would only repeat itself.
    var weeklyEquivalentPriceText: String? {
        guard let period = self.subscription?.subscriptionPeriod,
              period.normalized != (.week, 1) else {
            return nil
        }
        let weekly = (self.price / Decimal(period.days)) * Decimal(SubscriptionPeriod.Unit.week.days)
        let formatted = self.priceFormatStyle
            .precision(.integerAndFractionLength(integerLimits: 1..<4, fractionLimits: 2...2))
            .format(weekly)
        return String(localized: "\(formatted)/week")
    }

    /// The line of small print under the button: "Free for 7 days, then 79,99 €/year".
    var fullDescriptionText: String {
        guard let trial = self.freeTrialDuration else { return self.recurringPriceText }
        return String(localized: "Free for \(trial), then \(self.recurringPriceText)")
    }

    /// "Save 73%", shown on the plan that costs least per day — but only when
    /// there is a dearer plan on the same screen for it to beat.
    func savingBadge(comparedTo products: [Product]) -> String? {
        guard let mine = self.yearlyEquivalentPrice else { return nil }
        let others = products.filter { $0.id != self.id }.compactMap { $0.yearlyEquivalentPrice }
        guard let cheapestOther = others.min(), mine < cheapestOther,
              let dearest = others.max(), dearest > 0 else {
            return nil
        }
        let saving = Decimal(1) - mine / dearest
        let percentage = saving.formatted(.percent
            .precision(.integerAndFractionLength(integerLimits: ..<3, fractionLimits: 0...0)))
        return String(localized: "Save \(percentage)")
    }

    /// What a year on this plan costs, used only to rank plans against each other.
    private var yearlyEquivalentPrice: Decimal? {
        guard let period = self.subscription?.subscriptionPeriod, period.days > 0 else { return nil }
        return (self.price / Decimal(period.days)) * Decimal(SubscriptionPeriod.Unit.year.days)
    }

    private static func priceText(price: String, period: SubscriptionPeriod) -> String {
        let normalized = period.normalized
        guard normalized.value == 1 else {
            // "39,99 €/2 months"
            return String(localized: "\(price)/\(period.localizedDuration)")
        }
        switch normalized.unit {
        case .day: return String(localized: "\(price)/day")
        case .week: return String(localized: "\(price)/week")
        case .month: return String(localized: "\(price)/month")
        case .year: return String(localized: "\(price)/year")
        default: return price
        }
    }
}

/// Marks, in `Products.plist`, the plans the paywall is allowed to sell.
let productMetaOfferedKey: String = "offered"

/// The plans on sale right now.
///
/// Retired products stay listed in `Products.plist` with `offered` set to false:
/// the app still has to recognise a subscriber who bought the monthly plan back
/// when it existed, and StoreKit only hands back the products we ask for by id.
/// They simply no longer appear on the paywall.
func getOfferedSubscriptions(products: [Product], store: Store) -> [Product] {
    return products.filter {
        guard $0.subscription != nil,
              let metaDictionary = store.getProductData(forProductId: $0.id) as? [String: Any] else {
            return false
        }
        return (metaDictionary[productMetaOfferedKey] as? Bool) ?? false
    }
}
