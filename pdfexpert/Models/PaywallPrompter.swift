//
//  PaywallPrompter.swift
//  PdfExpert
//
//  When to ask for the sale, now that the onboarding no longer does.
//
//  Until 1.35 the paywall was the last step of the tour: it arrived before the
//  app had done anything for the customer, and 97% of installs saw it that way.
//  It now arrives after an action is finished — a document created, a page
//  scanned, a file converted — because by then there is something to pay for.
//
//  Two rules keep it from becoming a nuisance rather than an offer:
//
//  - **Never on top of something else.** A paywall asked for while an editor or
//    the scanner is covering the screen is either dropped by SwiftUI or lands on
//    a customer in the middle of a job. The request is remembered instead, and
//    spent when the screen is quiet — which is usually a second later, as the
//    flow closes behind itself.
//  - **Not twice in a minute.** Saving a document and then sharing it are two
//    finished actions a few seconds apart, and the share already has a paywall
//    of its own. `minimumInterval` is what stands between "after every action"
//    and three paywalls in twenty seconds.
//

import Foundation
import Combine
import Factory

extension Container {
    var paywallPrompter: Factory<PaywallPrompter> {
        self { PaywallPrompter() }.singleton
    }
}

@MainActor
final class PaywallPrompter: ObservableObject {

    /// The shortest gap between two offers. Not a cooling-off period — it is
    /// there for the burst, not for the day.
    static let minimumInterval: TimeInterval = 60

    /// True when an action has finished and the offer has not been made yet.
    /// `RootShellView` watches this and spends it as soon as nothing else is on
    /// screen.
    @Published private(set) var isPending: Bool = false

    @Injected(\.store) private var store

    private var lastPrompt: Date?
    private let now: () -> Date
    private var cancelBag = Set<AnyCancellable>()

    nonisolated init(now: @escaping () -> Date = Date.init) {
        self.now = now
        Task { @MainActor in self.start() }
    }

    private func start() {
        // Someone who pays between finishing the job and the screen coming free
        // must not then be shown a price list.
        self.store.isPremium
            .sink { [weak self] isPremium in
                guard isPremium else { return }
                Task { @MainActor in self?.cancelPending() }
            }
            .store(in: &self.cancelBag)
    }

    /// Called where the app already records that a job is done.
    ///
    /// A subscriber is never asked, and neither is someone who was asked a
    /// moment ago. Everyone else is, once, at the next quiet moment.
    func actionCompleted() {
        guard !self.store.isPremium.value else { return }
        if let lastPrompt = self.lastPrompt,
           self.now().timeIntervalSince(lastPrompt) < Self.minimumInterval {
            return
        }
        self.isPending = true
    }

    /// The offer is being made now: spend the request and start the clock.
    func markPrompted() {
        self.isPending = false
        self.lastPrompt = self.now()
    }

    /// Drops a pending request without making the offer — used when the customer
    /// subscribes in between, so the paywall does not arrive at someone who has
    /// just paid.
    func cancelPending() {
        self.isPending = false
    }
}
