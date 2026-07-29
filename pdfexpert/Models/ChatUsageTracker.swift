//
//  ChatUsageTracker.swift
//  PdfExpert
//
//  Tracks how many chat messages the user has sent in the current calendar month.
//
//  ⚠️ This is no longer where the cap is enforced. The proxy counts the same
//  allowance against Apple's `originalTransactionId` and answers
//  `429 monthly_limit_reached` on its own, which survives the reinstall that
//  resets these UserDefaults. What is left here is a local estimate: it decides
//  what the composer says and when it goes quiet, and it can disagree with the
//  server — after a reinstall, or on a second device, it will read full while
//  the month is already spent. Making the two agree means having the proxy
//  report the remaining count back and reading it from the response.
//

import Foundation
import Factory

protocol ChatUsageTracker {
    /// The monthly cap (from remote config).
    var monthlyLimit: Int { get }
    /// How many messages are still available in the current calendar month.
    var remainingMessages: Int { get }
    /// Records that one message was sent.
    func consumeMessage()
}

extension Container {
    var chatUsageTracker: Factory<ChatUsageTracker> {
        self { ChatUsageTrackerImpl() }.singleton
    }
}

class ChatUsageTrackerImpl: ChatUsageTracker {

    private static let keyPrefix = "chat_usage_"

    private let userDefaults: UserDefaults
    private let dateProvider: () -> Date
    private let capProvider: () -> Int

    /// - Parameters:
    ///   - userDefaults: backing store (injectable for tests).
    ///   - dateProvider: supplies "now" (injectable so month rollover can be tested).
    ///   - capProvider: supplies the monthly cap (defaults to the remote-config value).
    init(userDefaults: UserDefaults = .standard,
         dateProvider: @escaping () -> Date = { Date() },
         capProvider: @escaping () -> Int = {
            Container.shared.configService().remoteConfigData.value.chatMaxMessagesPerMonth
         }) {
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
        self.capProvider = capProvider
    }

    var monthlyLimit: Int {
        max(0, self.capProvider())
    }

    var remainingMessages: Int {
        max(0, self.monthlyLimit - self.consumedCount)
    }

    func consumeMessage() {
        self.userDefaults.set(self.consumedCount + 1, forKey: self.currentMonthKey)
    }

    // MARK: - Private

    private var consumedCount: Int {
        self.userDefaults.integer(forKey: self.currentMonthKey)
    }

    /// Key includes the current year-month, so a new month starts fresh with no
    /// explicit reset logic (the previous month's key is simply no longer read).
    private var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM"
        return Self.keyPrefix + formatter.string(from: self.dateProvider())
    }
}
