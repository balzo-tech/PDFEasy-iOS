//
//  DayPass.swift
//  PdfExpert
//
//  Twenty-four hours of PRO, bought outright.
//
//  Apple sells no auto-renewing subscription shorter than a week, so a day is a
//  consumable — and a consumable is a receipt, not an entitlement: it never
//  appears in `Transaction.currentEntitlements`, it is handed over once in
//  `Transaction.updates`, and from then on the app is the only thing that knows
//  whether it is still running. This type is that knowledge.
//
//  Three decisions worth keeping in mind:
//
//  - **The clock starts at Apple's `purchaseDate`, not at `Date()`.** The
//    purchase date is signed; the device clock is a setting. Over 24 hours the
//    difference barely matters for honest customers, but taking the signed one
//    costs nothing.
//  - **The expiry lives in `NSUbiquitousKeyValueStore`**, with `UserDefaults`
//    kept in step as a local mirror. A pass paid for at nine and lost to a
//    reinstall at ten is a refund request, and iCloud's key-value store is the
//    only place the app can write that survives one.
//  - **A transaction is applied once.** StoreKit re-delivers anything that was
//    never finished, so the id of the last pass applied is remembered: without
//    it, an interrupted launch would hand out a second day for free.
//

import Foundation
import Combine
import Factory
import StoreKit

extension Container {
    var dayPass: Factory<DayPass> {
        self { DayPass() }.singleton
    }
}

@MainActor
final class DayPass {

    /// True while a pass bought earlier is still running. Published, because
    /// `isPremium` is assembled from it and the app has to notice the moment it
    /// stops being true — including while the paywall is on screen.
    nonisolated let isActive: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)

    private let store: DayPassStorage
    private let now: () -> Date
    /// Fires when the current pass runs out, so the UI closes behind it rather
    /// than waiting for the next launch to notice. Touched from `deinit` as
    /// well as from the main actor, which is why it is spelled this way — the
    /// same reason as `StoreImpl.updateListenerTask`.
    nonisolated(unsafe) private var expiryTask: Task<Void, Never>?

    /// `nonisolated` for the same reason `StoreImpl`'s is: Factory builds its
    /// singletons wherever they are first asked for, which is not the main
    /// actor. Reading the clock is hopped onto it.
    nonisolated init(store: DayPassStorage = UbiquitousDayPassStorage(),
                     now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
        Task { @MainActor in self.refresh() }
    }

    deinit {
        self.expiryTask?.cancel()
    }

    /// When the running pass ends, or nil when there is none.
    var expiry: Date? {
        guard let expiry = self.store.expiry, expiry > self.now() else { return nil }
        return expiry
    }

    /// What is left, for the line that says so on the paywall.
    var timeRemaining: TimeInterval? {
        guard let expiry = self.expiry else { return nil }
        return expiry.timeIntervalSince(self.now())
    }

    /// Hands over a pass just paid for.
    ///
    /// Buying a second pass while the first is still running extends it rather
    /// than throwing away what was paid for: the new day is added to the end of
    /// the old one. Re-delivery of a transaction already applied changes
    /// nothing, which is what makes this safe to call from both `purchase()`
    /// and the update listener.
    @discardableResult
    func grant(transactionId: UInt64, purchaseDate: Date) -> Bool {
        guard self.store.lastTransactionId != transactionId else { return false }
        let from = max(purchaseDate, self.store.expiry ?? .distantPast)
        self.store.write(expiry: from.addingTimeInterval(K.DayPass.Duration),
                         transactionId: transactionId)
        self.refresh()
        return true
    }

    /// Re-reads the clock: called at launch, when the app comes back to the
    /// front, and after a purchase.
    func refresh() {
        let expiry = self.expiry
        self.isActive.send(expiry != nil)
        self.scheduleExpiry(at: expiry)
    }

    /// Nothing is left of a pass that has run out, so the keys go too: a stale
    /// expiry read as a date in the past is harmless, but a stale transaction id
    /// would refuse a legitimate re-delivery of a later purchase.
    func forgetIfExpired() {
        guard self.store.expiry != nil, self.expiry == nil else { return }
        self.store.clear()
    }

    private func scheduleExpiry(at expiry: Date?) {
        self.expiryTask?.cancel()
        guard let expiry else { return }
        let seconds = expiry.timeIntervalSince(self.now())
        guard seconds > 0 else { return }
        self.expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.forgetIfExpired()
            self?.refresh()
        }
    }
}

// MARK: - Storage

/// Where the expiry is kept. A protocol only so the tests can hold one in
/// memory: there is a single implementation, and it is the iCloud one.
protocol DayPassStorage {
    var expiry: Date? { get }
    var lastTransactionId: UInt64? { get }
    func write(expiry: Date, transactionId: UInt64)
    func clear()
}

/// iCloud's key-value store, with `UserDefaults` alongside it.
///
/// The ubiquitous store is the one that survives deleting and reinstalling the
/// app, which is the case that matters: it is also slow to arrive on a fresh
/// install, so every read prefers whichever of the two is further in the
/// future. A pass is never shortened by a store that has not synced yet.
struct UbiquitousDayPassStorage: DayPassStorage {

    static let expiryKey = "dayPassExpiry"
    static let transactionKey = "dayPassTransactionId"

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard

    var expiry: Date? {
        let cloudValue = self.cloud.double(forKey: Self.expiryKey)
        let localValue = self.local.double(forKey: Self.expiryKey)
        let latest = max(cloudValue, localValue)
        return latest > 0 ? Date(timeIntervalSince1970: latest) : nil
    }

    var lastTransactionId: UInt64? {
        let cloudValue = self.cloud.longLong(forKey: Self.transactionKey)
        let localValue = self.local.object(forKey: Self.transactionKey) as? Int64 ?? 0
        let known = cloudValue != 0 ? cloudValue : localValue
        return known != 0 ? UInt64(known) : nil
    }

    func write(expiry: Date, transactionId: UInt64) {
        let seconds = expiry.timeIntervalSince1970
        self.cloud.set(seconds, forKey: Self.expiryKey)
        self.cloud.set(Int64(bitPattern: transactionId), forKey: Self.transactionKey)
        self.cloud.synchronize()
        self.local.set(seconds, forKey: Self.expiryKey)
        self.local.set(Int64(bitPattern: transactionId), forKey: Self.transactionKey)
    }

    func clear() {
        self.cloud.removeObject(forKey: Self.expiryKey)
        self.cloud.removeObject(forKey: Self.transactionKey)
        self.cloud.synchronize()
        self.local.removeObject(forKey: Self.expiryKey)
        self.local.removeObject(forKey: Self.transactionKey)
    }
}
