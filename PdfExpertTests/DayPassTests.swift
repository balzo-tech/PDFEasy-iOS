//
//  DayPassTests.swift
//  PdfExpertTests
//
//  The 24-hour pass is the one entitlement Apple does not keep for us. A
//  consumable never appears in `Transaction.currentEntitlements`: it is handed
//  over once and then it is this app's job to remember what was paid for and
//  when it runs out. Everything that can go wrong with that is here — a day
//  handed out twice, a day lost, a day that outlives its hour.
//

import XCTest
import Combine
@testable import PdfExpert

@MainActor
final class DayPassTests: XCTestCase {

    private var storage: DayPassStorageMock!
    /// A clock the test moves by hand: the alternative is a test that sleeps for
    /// a day.
    private var clock: Date!

    override func setUp() {
        super.setUp()
        self.storage = DayPassStorageMock()
        self.clock = Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func makePass() -> DayPass {
        let pass = DayPass(store: self.storage, now: { self.clock })
        pass.refresh()   // the initializer's refresh is hopped onto the actor
        return pass
    }

    // MARK: - Buying one

    func testAPassBoughtNowRunsForTwentyFourHours() {
        let pass = self.makePass()
        XCTAssertFalse(pass.isActive.value)

        pass.grant(transactionId: 1, purchaseDate: self.clock)

        XCTAssertTrue(pass.isActive.value)
        XCTAssertEqual(pass.expiry, self.clock.addingTimeInterval(24 * 60 * 60))
    }

    /// The clock starts when Apple says the money moved, not when the app got
    /// round to hearing about it: a transaction delivered at the next launch,
    /// hours later, must not restart the day.
    func testTheDayIsCountedFromApplesPurchaseDate() {
        let pass = self.makePass()
        let boughtThreeHoursAgo = self.clock.addingTimeInterval(-3 * 60 * 60)

        pass.grant(transactionId: 1, purchaseDate: boughtThreeHoursAgo)

        XCTAssertEqual(pass.timeRemaining ?? 0, 21 * 60 * 60, accuracy: 1)
    }

    // MARK: - Not buying one twice

    /// StoreKit re-delivers anything that was never finished. Without this, a
    /// launch interrupted at the wrong moment would be worth a free day.
    func testTheSameTransactionIsNeverAppliedTwice() {
        let pass = self.makePass()
        pass.grant(transactionId: 42, purchaseDate: self.clock)
        let firstExpiry = pass.expiry

        let appliedAgain = pass.grant(transactionId: 42, purchaseDate: self.clock)

        XCTAssertFalse(appliedAgain)
        XCTAssertEqual(pass.expiry, firstExpiry)
    }

    /// Two passes are two days. Paying twice and being given one day would be
    /// the theft the other way round.
    func testASecondPassExtendsTheFirstRatherThanReplacingIt() {
        let pass = self.makePass()
        pass.grant(transactionId: 1, purchaseDate: self.clock)

        self.clock = self.clock.addingTimeInterval(2 * 60 * 60)
        pass.grant(transactionId: 2, purchaseDate: self.clock)

        XCTAssertEqual(pass.timeRemaining ?? 0, 46 * 60 * 60, accuracy: 1)
    }

    // MARK: - Running out

    func testAPassStopsCountingWhenItsDayIsOver() {
        let pass = self.makePass()
        pass.grant(transactionId: 1, purchaseDate: self.clock)

        self.clock = self.clock.addingTimeInterval(24 * 60 * 60 + 1)
        pass.refresh()

        XCTAssertFalse(pass.isActive.value)
        XCTAssertNil(pass.expiry)
        XCTAssertNil(pass.timeRemaining)
    }

    /// An expired pass is cleared, transaction id included — otherwise the id of
    /// a pass that ended yesterday would turn away the same customer's next
    /// purchase as a duplicate.
    func testAnExpiredPassIsForgottenSoTheNextOneCanBeBought() {
        let pass = self.makePass()
        pass.grant(transactionId: 7, purchaseDate: self.clock)

        self.clock = self.clock.addingTimeInterval(25 * 60 * 60)
        pass.forgetIfExpired()

        XCTAssertNil(self.storage.lastTransactionId)
        XCTAssertNil(self.storage.expiry)
    }

    func testAPassStillRunningIsNotForgotten() {
        let pass = self.makePass()
        pass.grant(transactionId: 7, purchaseDate: self.clock)

        self.clock = self.clock.addingTimeInterval(60 * 60)
        pass.forgetIfExpired()

        XCTAssertTrue(pass.isActive.value)
        XCTAssertEqual(self.storage.lastTransactionId, 7)
    }

    // MARK: - Surviving a reinstall

    /// The whole reason the expiry is written to iCloud: a customer who deletes
    /// the app at ten and reinstalls it at eleven has not spent their money on
    /// an hour.
    func testAPassSurvivesTheAppBeingReinstalled() {
        let pass = self.makePass()
        pass.grant(transactionId: 1, purchaseDate: self.clock)

        // A fresh install: new object, same storage — which is what the
        // ubiquitous key-value store gives back.
        let reinstalled = DayPass(store: self.storage, now: { self.clock })
        reinstalled.refresh()

        XCTAssertTrue(reinstalled.isActive.value)
    }
}

/// The two keys, held in memory. The real one writes them to iCloud and mirrors
/// them locally; what matters to these tests is only that they come back.
private final class DayPassStorageMock: DayPassStorage {

    private(set) var expiry: Date?
    private(set) var lastTransactionId: UInt64?

    func write(expiry: Date, transactionId: UInt64) {
        self.expiry = expiry
        self.lastTransactionId = transactionId
    }

    func clear() {
        self.expiry = nil
        self.lastTransactionId = nil
    }
}
