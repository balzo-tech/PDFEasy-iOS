//
//  EditorNavigationUITests.swift
//  PdfExpertUITests
//
//  The taps nobody could make.
//
//  Everything else in this project is verified from unit tests, scripts and
//  simulator screenshots, which between them cover what the app *is* and not
//  what happens when a finger lands on it. That gap is exactly where the
//  editor's tools live: a tool is chosen in a sheet, which dismisses while the
//  screen it asked for is pushed underneath it — two presentations in one turn,
//  and SwiftUI is entitled to drop either. A screenshot cannot tell you it
//  worked, because a screenshot is taken after the fact by something that never
//  touched anything.
//
//  So this bundle taps. It opens the panel, picks each tool the way a person
//  does, and — the part that matters — presses the back button and checks that
//  the document came back.
//
//  One thing to know before adding to this file: **`XCUIElement.tap()` does not
//  work in this app.** XCTest reports our SwiftUI buttons as `isHittable =
//  false` while `isEnabled` is true, and `tap()` waits for hittability and then
//  gives up. A synthesized touch at the same point lands correctly — verified
//  against the archive, which opens the editor from a coordinate tap and not
//  from `tap()`. So everything here goes through `tap(_:)` below, which taps the
//  centre of the element's frame.
//

import XCTest

final class EditorNavigationUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Every tool that answers with a pushed screen, and the title of the screen
    /// it must open. The two differ often enough to be worth writing down —
    /// "Split PDF" opens "Split pages into ranges".
    private static let pushedTools: [(tool: String, title: String)] = [
        ("reorderPages", "Reorder pages"),
        ("split", "Split pages into ranges"),
        ("extractPages", "Extract pages"),
        ("pageNumbers", "Page numbers"),
        ("watermark", "Watermark"),
        ("compress", "Compress PDF"),
        ("export", "Export PDF as…"),
        ("permissions", "PDF permissions"),
        ("metadata", "Document info"),
    ]

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    /// A UI test bundle installs the app fresh every time, so onboarding is
    /// waiting on the other side of every launch and the archive is empty.
    /// Pinned to English, because the screens are recognised by their titles.
    private func launch(premium: Bool = true) {
        self.app.launchArguments = ["-AppleLanguages", "(en)",
                                    "-onboardingShown", "YES",
                                    "-debugSeedArchive", "YES"]
        if premium {
            self.app.launchArguments += ["-debugPremium", "YES"]
        }
        self.app.launch()
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    // MARK: - The tools

    func testEveryPushedToolOpensItsScreenAndTheBackButtonReturnsToTheDocument() {
        self.launch()
        self.openTheFirstDocument()

        for tool in Self.pushedTools {
            self.openFromPanel(tool.tool)

            if !self.app.navigationBars[tool.title].waitForExistence(timeout: 10) {
                print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
                return XCTFail("\(tool.tool) did not open \(tool.title)")
            }

            self.tapBack(from: tool.title)

            XCTAssertTrue(self.editorIsShowing,
                          "the back button did not come back from \(tool.title)")
        }
    }

    /// The tools that answer with an alert rather than a screen. Same journey
    /// through the panel, and the alert has to be dismissable.
    func testTheImmediateToolsReportBackAndTheirAlertCloses() {
        self.launch()
        self.openTheFirstDocument()

        for tool in ["invertColors", "removeBlankPages"] {
            self.openFromPanel(tool)

            let ok = self.app.alerts.buttons["Ok"]
            XCTAssertTrue(ok.waitForExistence(timeout: 30), "\(tool) said nothing back")
            self.tap(ok)

            XCTAssertTrue(self.editorIsShowing)
        }
    }

    /// A tool opened and abandoned leaves nothing behind: no alert, no second
    /// screen, and the document is still the document. Twice, because the
    /// interesting failure is a tool that only misbehaves the second time.
    func testLeavingAToolTwiceInARowIsFine() {
        self.launch()
        self.openTheFirstDocument()

        for _ in 0..<2 {
            self.openFromPanel("compress")
            XCTAssertTrue(self.app.navigationBars["Compress PDF"].waitForExistence(timeout: 10))
            self.tapBack(from: "Compress PDF")
            XCTAssertTrue(self.editorIsShowing)
            XCTAssertFalse(self.app.alerts.element.exists, "backing out of Compress said something")
        }
    }

    /// Without a subscription a gated tool must show the paywall and nothing
    /// else, and closing the paywall must leave the document exactly as it was —
    /// not a dead screen, which is what a tool "doing nothing" looks like.
    func testAGatedToolShowsThePaywallAndClosesBackToTheDocument() {
        self.launch(premium: false)
        self.openTheFirstDocument()

        self.openFromPanel("watermark")

        let paywall = self.app.buttons["Continue"].firstMatch
        XCTAssertTrue(paywall.waitForExistence(timeout: 15),
                      "the watermark paywall never appeared")
        XCTAssertFalse(self.app.navigationBars["Watermark"].exists,
                       "the tool opened without a subscription")

        let close = self.app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "the paywall cannot be closed")
        self.tap(close)

        XCTAssertTrue(self.editorIsShowing, "closing the paywall left the document behind")
    }

    // MARK: - Getting there

    /// Into the editor the way a person gets there: from the archive, on a
    /// document. (`debugOpenEditor` cannot be used here — on a fresh install it
    /// races the first load and does nothing.)
    private func openTheFirstDocument() {
        let card = self.app.buttons["Meeting notes.pdf"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the seeded archive never appeared")
        self.tap(card)
        XCTAssertTrue(self.editorIsShowing, "the document did not open")
    }

    /// Opens the panel and taps a tool's tile, scrolling the grid to it if it
    /// starts below the fold — the panel holds sixteen tiles and a phone shows
    /// about eight.
    private func openFromPanel(_ tool: String) {
        let wrench = self.editorBar.buttons["Tools"]
        XCTAssertTrue(wrench.waitForExistence(timeout: 10), "the tool panel button is missing")
        self.tap(wrench)
        XCTAssertTrue(self.app.searchFields["Search tools"].waitForExistence(timeout: 10),
                      "the tool panel did not open")

        let tile = self.app.buttons["editorTool.\(tool)"]
        guard tile.waitForExistence(timeout: 10) else {
            print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            return XCTFail("\(tool) is not in the panel")
        }
        // Dragged by coordinate rather than through `scrollViews`: three scroll
        // views are in the tree at once — the archive's grid, the editor's
        // thumbnail strip and the panel's own — and the first match is not the
        // one on screen. The floating search field sits at the bottom of the
        // sheet, so a tile is only reachable well above it.
        var attempts = 0
        while tile.frame.maxY > self.panelSafeBottom, attempts < 8 {
            let start = self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let end = self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
            attempts += 1
        }
        self.tap(tile)
    }

    /// The system's own back button, which is the whole point: the leading item
    /// in the *tool's* navigation bar, and not ours. Scoped to that bar by name,
    /// because three navigation bars are in the tree at once — the archive's
    /// behind the editor cover, the editor's, and the tool's — and asking for
    /// "the first button in a navigation bar" picks whichever the tree happens
    /// to list first.
    private func tapBack(from title: String) {
        let bar = self.app.navigationBars[title]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "\(title) has no navigation bar")
        // Aimed at the chevron, not the middle: the back button is as wide as
        // the title it carries, and its centre sits over the editor's own title
        // menu on the screen underneath.
        let back = bar.buttons.element(boundBy: 0)
        back.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()
    }

    /// Above the panel's floating search field, which overlaps the last row of
    /// tiles.
    private var panelSafeBottom: CGFloat {
        self.app.windows.firstMatch.frame.maxY - 110
    }

    /// The editor's own navigation bar, titled with the document.
    private var editorBar: XCUIElement { self.app.navigationBars["Meeting notes.pdf"] }

    /// The document, recognised by the button that opens the tool panel — the
    /// one control the editor has and its tool screens do not.
    private var editorIsShowing: Bool {
        self.editorBar.buttons["Tools"].waitForExistence(timeout: 15)
    }

    /// See the note at the top of the file: `tap()` never fires in this app.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) never appeared", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
