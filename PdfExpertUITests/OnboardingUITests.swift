//
//  OnboardingUITests.swift
//  PdfExpertUITests
//
//  The five steps a first launch opens on, and the one thing they have to do:
//  advance. A title can linger in the tree through a step's transition, so a
//  title existing proves nothing — each check asks whether the words are inside
//  the window.
//
//  See the note at the top of EditorNavigationUITests about `tap()`: it never
//  fires in this app, so everything here taps by coordinate.
//

import XCTest

final class OnboardingUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Enough of each page's title to recognise it. The last one is a fragment
    /// because it opens with the number of tools in the catalog, which moves on
    /// its own — the tools that need the online service leave it when that is
    /// switched off.
    private static let pages = [
        "Scan anything into a PDF",
        "Turn any file into a PDF",
        "Sign without printing",
        "Ask your document",
        "tools in one app",
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

        XCTAssertTrue(self.app.buttons["Try for free"].firstMatch.waitForExistence(timeout: 20),
                      "the last page did not open the paywall")
        self.attachScreenshot(named: "Onboarding-paywall")
    }

    /// Whether the page carrying this title is the one on screen — matched on a
    /// fragment, and checked by frame rather than by existence, since a title can
    /// linger in the tree through the step's transition.
    private func isOnScreen(_ label: String) -> Bool {
        let element = self.app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", label))
            .firstMatch
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
