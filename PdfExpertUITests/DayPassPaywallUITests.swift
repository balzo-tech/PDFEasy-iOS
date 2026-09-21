//
//  DayPassPaywallUITests.swift
//  PdfExpertUITests
//
//  The paywall a South African sees: a day and a week, both charged today,
//  and no free trial anywhere on the screen.
//
//  It cannot be reached by running the app normally: the storefront decides,
//  and a simulator takes it from whoever is signed in. `debugStorefront` is the
//  stand-in.
//
//  ⚠️ The products themselves come from App Store Connect, not from any
//  `.storekit` file — a StoreKit configuration on the scheme is not applied to
//  UI tests, and neither is `SKTestSession`, which only reaches an app it shares
//  a process with. So this test needs `eu.balzo.pdfexpert.staging.daypass` to be
//  at least `READY_TO_SUBMIT`: if it is ever removed, this fails, and the
//  failure is telling the truth — the paywall would fall back to three plans.
//
//  The screenshot this attaches is also the one App Store Connect asks for
//  before a new in-app purchase can be submitted.
//
//  Same tapping rule as the rest of this target: `XCUIElement.tap()` never
//  fires in this app, so every touch goes through `tap(_:)`.
//

import XCTest

final class DayPassPaywallUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    func testTheDayPassStorefrontIsSoldADayAndAWeekAndNoTrial() {
        self.app.launchArguments = ["-AppleLanguages", "(en)",
                                    "-onboardingShown", "YES",
                                    "-debugStorefront", "ZAF"]
        self.app.launch()

        let pro = self.app.buttons["Upgrade to PRO"].firstMatch
        XCTAssertTrue(pro.waitForExistence(timeout: 30), "the PRO button is not in the header")
        self.tap(pro)

        let pass = self.app.staticTexts["24-hour pass"].firstMatch
        let passIsOnSale = pass.waitForExistence(timeout: 30)
        self.attachScreenshot(named: passIsOnSale ? "Paywall-ZAF-day-pass" : "Paywall-ZAF-fallback")
        XCTAssertTrue(passIsOnSale,
                      "the 24-hour pass is not on the paywall in a day-pass storefront")

        // The week is the other half of the offer, and it is the one preselected:
        // the pass is the way in for someone who will not subscribe, not the
        // thing to lead with.
        XCTAssertTrue(self.app.staticTexts["Weekly"].firstMatch.exists,
                      "the weekly plan should be on this paywall too")

        // Nothing here is free, and the button must not say it is.
        XCTAssertFalse(self.app.buttons["Try for free"].firstMatch.exists,
                       "a paywall with no trial on it offered one anyway")
        XCTAssertTrue(self.app.buttons["Continue"].firstMatch.exists,
                      "the button should ask for the sale, not for a trial")

        self.attachScreenshot(named: "Paywall-ZAF-day-pass")
    }

    // MARK: - Helpers

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
