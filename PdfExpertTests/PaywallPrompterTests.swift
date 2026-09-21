//
//  PaywallPrompterTests.swift
//  PdfExpertTests
//
//  Where the paywall is asked for, now that the onboarding no longer asks.
//
//  The rules are few and each of them is the answer to a way of being a
//  nuisance: never to someone who already pays, never twice in the same burst,
//  and never at all until a piece of work is actually finished.
//

import XCTest
import StoreKit
import Combine
import Factory
@testable import PdfExpert

@MainActor
final class PaywallPrompterTests: XCTestCase {

    private var store: PromptStoreMock!
    private var clock: Date!

    override func setUp() {
        super.setUp()
        self.store = PromptStoreMock()
        self.clock = Date(timeIntervalSince1970: 1_700_000_000)
        Container.shared.store.register { self.store }
    }

    override func tearDown() {
        Container.shared.store.reset()
        super.tearDown()
    }

    private func makePrompter() -> PaywallPrompter {
        PaywallPrompter(now: { self.clock })
    }

    func testNothingIsOwedBeforeAnyWorkIsDone() {
        XCTAssertFalse(self.makePrompter().isPending)
    }

    func testAFinishedActionOwesAnOffer() {
        let prompter = self.makePrompter()
        prompter.actionCompleted()
        XCTAssertTrue(prompter.isPending)
    }

    /// The offer is spent when it is made: a customer who closed the paywall
    /// should not find it again the moment the screen settles.
    func testMakingTheOfferSpendsIt() {
        let prompter = self.makePrompter()
        prompter.actionCompleted()

        prompter.markPrompted()

        XCTAssertFalse(prompter.isPending)
    }

    /// Saving a document and sharing it are two finished actions seconds apart,
    /// and the share has a paywall of its own.
    func testASecondActionWithinTheMinuteAsksNothing() {
        let prompter = self.makePrompter()
        prompter.actionCompleted()
        prompter.markPrompted()

        self.clock = self.clock.addingTimeInterval(30)
        prompter.actionCompleted()

        XCTAssertFalse(prompter.isPending)
    }

    func testAnActionAfterTheMinuteAsksAgain() {
        let prompter = self.makePrompter()
        prompter.actionCompleted()
        prompter.markPrompted()

        self.clock = self.clock.addingTimeInterval(61)
        prompter.actionCompleted()

        XCTAssertTrue(prompter.isPending)
    }

    func testASubscriberIsNeverAsked() {
        self.store.isPremium.send(true)
        let prompter = self.makePrompter()

        prompter.actionCompleted()

        XCTAssertFalse(prompter.isPending)
    }

    /// The gap between finishing the work and the screen coming free is where
    /// someone can pay — from the PRO button, or from a gate on the way out.
    /// The offer owed a second ago must not then arrive.
    func testPayingInTheMeantimeCancelsAnOfferAlreadyOwed() {
        let prompter = self.makePrompter()
        prompter.actionCompleted()
        XCTAssertTrue(prompter.isPending)

        prompter.cancelPending()

        XCTAssertFalse(prompter.isPending)
    }
}

@MainActor
private final class PromptStoreMock: Store {
    nonisolated let isPremium: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    nonisolated let originalTransactionId: CurrentValueSubject<String?, Never> = CurrentValueSubject(nil)

    var subscriptions: [Product] { [] }
    var consumables: [Product] { [] }
    var purchasedSubscriptions: [Product] { [] }
    var subscriptionGroupStatus: RenewalState? { nil }

    func refreshAll() async throws {}
    func requestProducts() async throws {}
    func purchase(_ product: Product) async throws -> Transaction? { nil }
    func isPurchased(_ product: Product) async throws -> Bool { false }
    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        throw StoreError.failedVerification
    }
    func updateCustomerProductStatus() async {}
    nonisolated func getProductData(forProductId productId: String) -> Any? { nil }
    nonisolated func sortByPrice(_ products: [Product]) -> [Product] { products }
}
