//
//  PaywallAnalyticsTests.swift
//  PdfExpertTests
//
//  The three events that fill the gap between `subscription_shown` and
//  `checkout_completed`. Nine customers in ten leave the paywall without buying,
//  and until these existed the app could not say whether they closed the screen,
//  never pressed the button, or pressed it and were turned away by their bank.
//
//  What is worth a test here is not the tracking itself but the strings: every
//  value below lands in a GA4 report as a dimension, and a value renamed later
//  does not correct the past — it splits the series in two, leaving a funnel
//  that silently reads half the traffic.
//

import XCTest
@testable import PdfExpert

final class PaywallAnalyticsTests: XCTestCase {

    // MARK: - The exit from the paywall

    func testEveryPaywallExitHasItsOwnValue() {
        XCTAssertEqual(AnalyticsPaywallExit.notShown.trackingParameterValue, "not_shown")
        XCTAssertEqual(AnalyticsPaywallExit.declined.trackingParameterValue, "declined")
        XCTAssertEqual(AnalyticsPaywallExit.accepted.trackingParameterValue, "accepted")
    }

    func testTheDismissalIsOneEventWhateverTheExit() {
        XCTAssertEqual(AnalyticsEvent.subscriptionDismissed(exit: .notShown).customEventName,
                       "subscription_dismissed")
        XCTAssertEqual(AnalyticsEvent.subscriptionDismissed(exit: .accepted).customEventName,
                       "subscription_dismissed")
    }

    /// The exit is a parameter, not three separate events: a funnel asks how many
    /// left, and only then which of them were asked to stay.
    func testTheExitTravelsAsAParameter() {
        let parameters = AnalyticsEvent.subscriptionDismissed(exit: .declined).parameters
        XCTAssertEqual(parameters?["paywall_exit"] as? String, "declined")
    }

    // MARK: - The failed checkout

    func testEveryCheckoutFailureHasItsOwnValue() {
        XCTAssertEqual(AnalyticsCheckoutFailure.userCancelled.trackingParameterValue, "user_cancelled")
        XCTAssertEqual(AnalyticsCheckoutFailure.pending.trackingParameterValue, "pending")
        XCTAssertEqual(AnalyticsCheckoutFailure.verificationFailed.trackingParameterValue, "verification_failed")
        XCTAssertEqual(AnalyticsCheckoutFailure.unknownResult.trackingParameterValue, "unknown_result")
        XCTAssertEqual(AnalyticsCheckoutFailure.error(code: "SKErrorDomain.2").trackingParameterValue, "error")
    }

    /// The code is what separates a declined card from a network that dropped,
    /// and only the `error` case has one to report.
    func testOnlyAnErrorCarriesACode() {
        XCTAssertEqual(AnalyticsCheckoutFailure.error(code: "SKErrorDomain.2").trackingErrorCode,
                       "SKErrorDomain.2")
        XCTAssertNil(AnalyticsCheckoutFailure.userCancelled.trackingErrorCode)
        XCTAssertNil(AnalyticsCheckoutFailure.pending.trackingErrorCode)
        XCTAssertNil(AnalyticsCheckoutFailure.verificationFailed.trackingErrorCode)
        XCTAssertNil(AnalyticsCheckoutFailure.unknownResult.trackingErrorCode)
    }

    /// The app is sold in sixteen languages and the report has to be readable in
    /// one: the domain and code are the same string everywhere, where the
    /// message Apple writes is not. They also say nothing about the customer.
    func testTheFailureCodeIsNeitherLocalizedNorPersonal() {
        let error = NSError(domain: "SKErrorDomain", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "L'operazione non è stata completata"
        ])
        XCTAssertEqual(StoreImpl.failureCode(forError: error), "SKErrorDomain.2")
    }

    func testTheFailureCodeSurvivesAnUnknownError() {
        enum Whatever: Error { case somethingElse }
        let code = StoreImpl.failureCode(forError: Whatever.somethingElse)
        XCTAssertFalse(code.isEmpty)
        XCTAssertTrue(code.contains("."), "Expected a domain and a code, got \(code)")
    }
}
