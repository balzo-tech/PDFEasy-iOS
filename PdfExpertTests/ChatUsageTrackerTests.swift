//
//  ChatUsageTrackerTests.swift
//  PdfExpertTests
//
//  Unit tests for the monthly chat-message cap and the document-text truncation
//  helper. No network is exercised.
//

import XCTest
@testable import PdfExpert

final class ChatUsageTrackerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        self.suiteName = "ChatUsageTrackerTests-\(UUID().uuidString)"
        self.defaults = UserDefaults(suiteName: self.suiteName)
    }

    override func tearDown() {
        self.defaults.removePersistentDomain(forName: self.suiteName)
        self.defaults = nil
        self.suiteName = nil
        super.tearDown()
    }

    private func makeTracker(cap: Int, dateProvider: @escaping () -> Date) -> ChatUsageTrackerImpl {
        ChatUsageTrackerImpl(userDefaults: self.defaults,
                             dateProvider: dateProvider,
                             capProvider: { cap })
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    /// The default remote-config cap (20) must be honored end-to-end.
    func testDefaultCapOfTwentyIsHonored() {
        let tracker = self.makeTracker(cap: 20, dateProvider: { Date() })
        XCTAssertEqual(tracker.monthlyLimit, 20)
        XCTAssertEqual(tracker.remainingMessages, 20)
    }

    /// Each consumed message decrements the remaining count by one.
    func testConsumeDecrementsRemaining() {
        let tracker = self.makeTracker(cap: 20, dateProvider: { Date() })
        tracker.consumeMessage()
        XCTAssertEqual(tracker.remainingMessages, 19)
        tracker.consumeMessage()
        XCTAssertEqual(tracker.remainingMessages, 18)
    }

    /// Once the cap is reached the remaining count is exactly zero and never goes
    /// negative, even if more messages are (defensively) consumed.
    func testExhaustionClampsAtZero() {
        let tracker = self.makeTracker(cap: 3, dateProvider: { Date() })
        for _ in 0..<3 { tracker.consumeMessage() }
        XCTAssertEqual(tracker.remainingMessages, 0)

        tracker.consumeMessage()
        XCTAssertEqual(tracker.remainingMessages, 0, "remaining must never go negative")
    }

    /// Usage is keyed by calendar month, so crossing into a new month resets the
    /// available allowance while the previous month's count stays recorded.
    func testMonthRolloverResetsUsage() {
        var now = self.date(year: 2026, month: 1, day: 15)
        let tracker = ChatUsageTrackerImpl(userDefaults: self.defaults,
                                           dateProvider: { now },
                                           capProvider: { 20 })

        tracker.consumeMessage()
        tracker.consumeMessage()
        XCTAssertEqual(tracker.remainingMessages, 18)

        // Move into the next month: the allowance must be full again.
        now = self.date(year: 2026, month: 2, day: 1)
        XCTAssertEqual(tracker.remainingMessages, 20, "usage must reset on month change")

        tracker.consumeMessage()
        XCTAssertEqual(tracker.remainingMessages, 19)

        // Going back to January must surface the previously stored count.
        now = self.date(year: 2026, month: 1, day: 28)
        XCTAssertEqual(tracker.remainingMessages, 18, "the previous month's usage must be preserved")
    }
}

final class OpenAiChatPdfTruncationTests: XCTestCase {

    /// Text within the budget is returned unchanged and not flagged as truncated.
    func testTextWithinBudgetIsUnchanged() {
        let text = "A short document."
        let result = OpenAiChatPdfManagerImpl.truncateDocumentText(text, maxCharacters: 100)
        XCTAssertEqual(result.text, text)
        XCTAssertFalse(result.truncated)
    }

    /// Text exactly at the budget boundary is not truncated.
    func testTextAtExactBudgetIsNotTruncated() {
        let text = String(repeating: "b", count: 100)
        let result = OpenAiChatPdfManagerImpl.truncateDocumentText(text, maxCharacters: 100)
        XCTAssertEqual(result.text, text)
        XCTAssertFalse(result.truncated)
    }

    /// Text over the budget is cut to the budget length and flagged as truncated.
    func testTextOverBudgetIsTruncated() {
        let text = String(repeating: "a", count: 500)
        let result = OpenAiChatPdfManagerImpl.truncateDocumentText(text, maxCharacters: 100)
        XCTAssertEqual(result.text.count, 100)
        XCTAssertTrue(result.truncated)
        XCTAssertEqual(result.text, String(repeating: "a", count: 100))
    }
}
