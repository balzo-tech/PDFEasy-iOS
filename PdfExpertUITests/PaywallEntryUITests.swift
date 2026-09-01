//
//  PaywallEntryUITests.swift
//  PdfExpertUITests
//
//  The way into the paywall that does not go through a document.
//
//  Everywhere else the paywall arrives as an answer: something is being shared,
//  and it cannot leave without a subscription. Someone who has already decided
//  to pay had no way of saying so — they had to start a job and abandon it
//  halfway to reach the price. The "PRO" button in the header is that way in,
//  and these two tests hold both halves of it: it is there for a stranger, and
//  it is gone for a subscriber.
//
//  Same tapping rule as the other files here: `XCUIElement.tap()` never fires in
//  this app, so every touch goes through `tap(_:)`.
//

import XCTest

final class PaywallEntryUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    /// Pinned to English: the button is found by what VoiceOver reads out, and
    /// the paywall by the button on it.
    private func launch(premium: Bool) {
        self.app.launchArguments = ["-AppleLanguages", "(en)",
                                    "-onboardingShown", "YES",
                                    "-debugSeedArchive", "YES"]
        if premium {
            self.app.launchArguments += ["-debugPremium", "YES"]
        }
        self.app.launch()
    }

    func testTheHeaderButtonOpensThePaywallWithoutTouchingADocument() {
        self.launch(premium: false)

        let pro = self.app.buttons["Upgrade to PRO"].firstMatch
        XCTAssertTrue(pro.waitForExistence(timeout: 20),
                      "the PRO button is not in the header")
        self.attachScreenshot(named: "Header-with-PRO")
        self.tap(pro)

        XCTAssertTrue(self.app.buttons["Try for free"].firstMatch.waitForExistence(timeout: 15),
                      "the PRO button did not open the paywall")

        // And it lets go of the app again: a door that cannot be closed is a
        // wall. The archive is behind it, untouched — nothing was started.
        let close = self.app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "the paywall cannot be closed")
        self.tap(close)
        XCTAssertTrue(self.app.buttons["Upgrade to PRO"].firstMatch.waitForExistence(timeout: 10),
                      "closing the paywall did not come back to the header")
    }

    func testTheHeaderButtonIsAbsentForASubscriber() {
        self.launch(premium: true)

        // Something from the shell has to be on screen first, or this asserts
        // against a window that has not been built yet and passes for the wrong
        // reason.
        XCTAssertTrue(self.app.buttons["Settings"].firstMatch.waitForExistence(timeout: 20),
                      "the app never finished launching")
        XCTAssertFalse(self.app.buttons["Upgrade to PRO"].firstMatch.exists,
                       "a subscriber is still being sold the subscription")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: self.app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) never appeared", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
