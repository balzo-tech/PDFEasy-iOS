//
//  AppleAttributionPlatformTests.swift
//  PdfExpertTests
//
//  The one piece of judgement in the attribution platform: StoreKit describes a
//  subscription period as a unit and a count — a weekly plan can arrive as
//  "7 days" or "1 week" — while the attribution SDK segments revenue into three
//  buckets. Get the mapping wrong and a keyword's weekly plans are reported as
//  monthly, which is the sort of error that is only visible in a dashboard,
//  months later, as a number nobody can explain.
//

import XCTest
import StoreKit
@testable import PdfExpert

final class AppleAttributionPlatformTests: XCTestCase {

    private typealias Platform = AppleAttributionPlatform

    func testAWeekIsAWeekHoweverItIsSpelled() {
        XCTAssertEqual(Platform.period(unit: .week, value: 1), .weekly)
        // App Store Connect offers "1 week" as seven days.
        XCTAssertEqual(Platform.period(unit: .day, value: 7), .weekly)
    }

    func testAMonthIsAMonthHoweverItIsSpelled() {
        XCTAssertEqual(Platform.period(unit: .month, value: 1), .monthly)
        XCTAssertEqual(Platform.period(unit: .day, value: 30), .monthly)
        XCTAssertEqual(Platform.period(unit: .week, value: 4), .monthly)
    }

    func testAYearIsAYearHoweverItIsSpelled() {
        XCTAssertEqual(Platform.period(unit: .year, value: 1), .annual)
        XCTAssertEqual(Platform.period(unit: .month, value: 12), .annual)
        XCTAssertEqual(Platform.period(unit: .day, value: 365), .annual)
        XCTAssertEqual(Platform.period(unit: .week, value: 52), .annual)
    }

    /// The in-between periods App Store Connect also allows. None of them can
    /// report as something longer than they are: a two-month plan billed as
    /// annual would overstate what a keyword earns.
    func testTheAwkwardPeriodsRoundDown() {
        XCTAssertEqual(Platform.period(unit: .month, value: 2), .monthly)
        XCTAssertEqual(Platform.period(unit: .month, value: 6), .monthly)
        XCTAssertEqual(Platform.period(unit: .day, value: 3), .weekly)
        XCTAssertEqual(Platform.period(unit: .week, value: 2), .weekly)
    }
}
