//
//  MarketProfile.swift
//  PdfExpert
//
//  What the app sells here, and what it does not.
//
//  One list in Firebase — `day_pass_storefronts` — names the storefronts where
//  two things change at once:
//
//  - **the paywall sells a day and a week**, both charged immediately, instead
//    of three subscriptions one of which opens on a free trial;
//  - **ChatPDF is not offered at all.** Every message costs real money at
//    OpenAI, and these are the markets where almost nobody pays: a 2,50 €
//    pass that opens an unmetered assistant is a way to lose money faster than
//    the advertising already does.
//
//  The country comes from `Storefront.current`, which is the App Store that
//  will take the payment — never `Locale`, which is the language the phone is
//  set to, and never the IP address, which is where the phone happens to be.
//  The three disagree often enough to matter: GA4's country for this app is the
//  IP and has already produced a "Morocco" that was Spanish paid traffic.
//

import Foundation
import Combine
import Factory
import StoreKit

extension Container {
    var marketProfile: Factory<MarketProfile> {
        self { MarketProfile() }.singleton
    }
}

@MainActor
final class MarketProfile: ObservableObject {

    /// ISO 3166-1 alpha-3, as StoreKit spells it ("ZAF"). Nil until StoreKit
    /// answers, which is a moment or two after launch — everything below treats
    /// "not known yet" as "an ordinary market", so a slow answer can only ever
    /// show the paywall we have always shown.
    @Published private(set) var storefront: String?

    @Injected(\.configService) private var configService

    private var cancelBag = Set<AnyCancellable>()

    nonisolated init() {
        Task { @MainActor in self.start() }
    }

    private func start() {
        // The list can arrive after the first screen is on the phone: Firebase
        // is fetched at launch, not before it. Republishing keeps the tab bar
        // and the paywall honest when it lands.
        self.configService.remoteConfigData
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &self.cancelBag)
        Task { await self.refresh() }
    }

    func refresh() async {
        self.storefront = await Storefront.current?.countryCode
    }

    /// True where the paywall offers the 24-hour pass and the weekly plan.
    var sellsDayPass: Bool {
        guard let storefront = self.storefront?.uppercased() else { return false }
        return self.configService.remoteConfigData.value.dayPassStorefronts.contains(storefront)
    }

    /// False where ChatPDF is kept off the shelf entirely — no tab, no tool, no
    /// deep link landing on it.
    var offersChat: Bool { !self.sellsDayPass }
}
