//
//  OnboardingUITests.swift
//  PdfExpertUITests
//
//  The four screens a first launch opens on, and the one thing they have to do:
//  advance. The pager keeps every page in the tree at once, so a title existing
//  proves nothing — each check asks whether the page is actually on screen.
//
//  See the note at the top of EditorNavigationUITests about `tap()`: it never
//  fires in this app, so everything here taps by coordinate.
//

import XCTest

final class OnboardingUITests: XCTestCase {

    private var app: XCUIApplication!

    private static let pages = [
        "Scan anything into a PDF",
        "Turn any file into a PDF",
        "Sign without printing",
        "Ask your document",
    ]

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    /// Reinstalling the app does not clear its defaults, so a run that has
    /// already been through onboarding once would never see it again. The flag is
    /// set back to NO explicitly. Pinned to English: the pages are recognised by
    /// their titles.
    private func launch() {
        self.app.launchArguments = ["-AppleLanguages", "(en)", "-onboardingShown", "NO"]
        self.app.launch()
    }

    func testEveryPageIsReachableAndTheLastOneOpensThePaywall() {
        self.launch()

        // The welcome screen comes first; onboarding is pushed on top of it.
        self.attachScreenshot(named: "Onboarding-0-welcome")
        self.tap(self.app.buttons["Start"].firstMatch)

        for (index, title) in Self.pages.enumerated() {
            let onScreen = self.isOnScreen(title)
            self.attachScreenshot(named: "Onboarding-\(index + 1)")
            if !onScreen {
                print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            }
            XCTAssertTrue(onScreen, "page \(index + 1), \(title), is not on screen")
            // The last step's button says what it does — it leaves the tour.
            let isLast = index == Self.pages.count - 1
            self.tap(self.app.buttons[isLast ? "Get started" : "Continue"].firstMatch)
        }

        XCTAssertTrue(self.app.buttons["Start free trial"].firstMatch.waitForExistence(timeout: 20),
                      "the last page did not open the paywall")
        self.attachScreenshot(named: "Onboarding-paywall")
    }

    /// Every page of the pager is in the tree from the start, so existence is not
    /// the question — whether the label sits inside the window is.
    private func isOnScreen(_ label: String) -> Bool {
        let element = self.app.staticTexts[label]
        guard element.waitForExistence(timeout: 10) else { return false }
        let window = self.app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let frame = element.frame
            if frame.width > 0, window.insetBy(dx: -1, dy: -1).contains(frame) { return true }
            usleep(200_000)
        }
        return false
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
