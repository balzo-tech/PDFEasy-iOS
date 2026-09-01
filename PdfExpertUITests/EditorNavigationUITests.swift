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
    ///
    /// The third field is what to type into the panel's search when the tile is
    /// below the fold — it is the *tool's* name, which is not always the name of
    /// the screen it opens: "Split PDF" opens "Split pages into ranges".
    private static let pushedTools: [(tool: String, title: String, query: String)] = [
        ("reorderPages", "Reorder pages", "Reorder"),
        ("split", "Split pages into ranges", "Split"),
        ("extractPages", "Extract pages", "Extract"),
        ("pageNumbers", "Page numbers", "Page numbers"),
        ("watermark", "Watermark", "Watermark"),
        ("compress", "Compress PDF", "Compress"),
        ("export", "Export PDF as…", "Export"),
        ("permissions", "PDF permissions", "permissions"),
        ("metadata", "Document info", "Document info"),
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
            self.openFromPanel(tool.tool, searchingFor: tool.query)

            if !self.screenIsShowing(tool.title) {
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

        for (tool, query) in [("invertColors", "Invert"), ("removeBlankPages", "Remove blank")] {
            self.openFromPanel(tool, searchingFor: query)

            // Asked for by its button and not through `app.alerts`: on Mac
            // Catalyst a SwiftUI `.alert` comes through the tree as a *Sheet*,
            // so `app.alerts` is empty while the alert is plainly on screen.
            let ok = self.app.buttons["Ok"].firstMatch
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
            self.openFromPanel("compress", searchingFor: "Compress")
            XCTAssertTrue(self.screenIsShowing("Compress PDF"))
            self.tapBack(from: "Compress PDF")
            XCTAssertTrue(self.editorIsShowing)
            XCTAssertFalse(self.app.buttons["Ok"].firstMatch.exists,
                           "backing out of Compress said something")
        }
    }

    /// The editor's tools no longer stop a non-subscriber at the door: they run
    /// on device and leave the result in the document. Watermark is the one that
    /// used to gate here.
    func testAToolThatUsedToGateOpensWithoutASubscription() {
        self.launch(premium: false)
        self.openTheFirstDocument()

        self.openFromPanel("watermark", searchingFor: "Watermark")

        XCTAssertTrue(self.screenIsShowing("Watermark"),
                      "the tool did not open for a non-subscriber")
        XCTAssertFalse(self.app.buttons["Continue"].firstMatch.exists,
                       "the paywall is still in front of the tool")
    }

    /// Where the paywall lives now: on the way out. Sharing is what takes the
    /// document off the device, and it is the one thing a non-subscriber cannot
    /// do — with the yearly plan's renewal notice on the paywall it opens.
    func testSharingShowsThePaywallCarryingTheRenewalNotice() {
        self.launch(premium: false)
        self.openTheFirstDocument()

        self.openFromPanelBySearching("share", query: "Share")

        let paywall = self.app.buttons["Try for free"].firstMatch
        XCTAssertTrue(paywall.waitForExistence(timeout: 15),
                      "sharing did not show the paywall")
        XCTAssertTrue(self.app.staticTexts["With the yearly plan, we let you know before it expires."].exists,
                      "the renewal notice is not on the paywall")

        self.attachScreenshot(named: "Paywall")

        let close = self.app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "the paywall cannot be closed")
        self.tap(close)

        XCTAssertTrue(self.editorIsShowing, "closing the paywall left the document behind")
    }

    /// The shape of the paywall since the monthly plan came back: three cards,
    /// the yearly one still preselected, and nothing selected alongside it.
    ///
    /// The monthly plan was retired once and is on sale again at 7,99 € —
    /// deliberately above a twelfth of the yearly one, because the paywall ranks
    /// the plans by what a year on each costs and would otherwise hand the
    /// "Save …" badge, and the preselection with it, to the plan that brings in
    /// a fraction of the money. Twelve monthly charges come to 95,88 €, against
    /// 69,99 € for a year.
    ///
    /// That is the price of `monthly`, the variant without an introductory
    /// offer, and it has been live since 2023: unlike `monthly.freetrial` there
    /// is no price change to wait for, so this test no longer doubles as a
    /// release gate.
    ///
    /// What the paywall has to sell comes from App Store Connect at run time, so
    /// this cannot insist on the weekly card being there — a product that is not
    /// yet approved simply does not arrive. It checks the weekly card only when
    /// StoreKit hands it over, and always checks the two things that are ours:
    /// the monthly plan is on sale and exactly one card is chosen.
    func testThePaywallOffersTheMonthlyPlanWithTheYearlyStillPreselected() {
        self.launch(premium: false)
        self.openTheFirstDocument()

        self.openFromPanelBySearching("share", query: "Share")

        XCTAssertTrue(self.app.buttons["Try for free"].firstMatch.waitForExistence(timeout: 15),
                      "sharing did not show the paywall")

        // Each card combines its children into one accessibility element, so a
        // plan is a button whose label starts with the plan's name and not a
        // static text of its own.
        let yearly = self.card(named: "Yearly")
        XCTAssertTrue(yearly.exists, "the yearly plan is missing")
        XCTAssertTrue(yearly.isSelected, "the yearly plan is not the one preselected")

        let monthly = self.card(named: "Monthly")
        XCTAssertTrue(monthly.exists, "the monthly plan is not on sale")
        XCTAssertFalse(monthly.isSelected, "the monthly plan took the preselection")

        let weekly = self.card(named: "Weekly")
        if weekly.exists {
            XCTAssertFalse(weekly.isSelected, "two plans are selected at once")
        }
    }

    /// The free trial is what the yearly plan has and the other two do not.
    ///
    /// Every plan exists in App Store Connect twice, with an introductory offer
    /// and without, and `Products.plist` picks the variant on sale. Since 1.30
    /// the weekly and monthly cards are the no-trial ones: they charge on the
    /// spot, which leaves the trial as a reason to take the yearly plan rather
    /// than something every card gives away.
    ///
    /// A card combines its children into a single accessibility label, so the
    /// promise — "Try it now for free", and the length of the trial — is either
    /// part of that label or it is not on the card at all.
    func testOnlyTheYearlyPlanOpensOnAFreeTrial() {
        self.launch(premium: false)
        self.openTheFirstDocument()

        self.openFromPanelBySearching("share", query: "Share")

        let yearly = self.card(named: "Yearly")
        XCTAssertTrue(yearly.waitForExistence(timeout: 15), "the yearly plan is missing")
        XCTAssertTrue(yearly.label.localizedCaseInsensitiveContains("free"),
                      "the yearly plan stopped offering the free trial: \(yearly.label)")

        let monthly = self.card(named: "Monthly")
        XCTAssertTrue(monthly.exists, "the monthly plan is not on sale")
        XCTAssertFalse(monthly.label.localizedCaseInsensitiveContains("free"),
                       "the monthly plan still promises a free trial: \(monthly.label)")

        // As above: the weekly plan is checked only if StoreKit hands it over.
        let weekly = self.card(named: "Weekly")
        if weekly.exists {
            XCTAssertFalse(weekly.label.localizedCaseInsensitiveContains("free"),
                           "the weekly plan still promises a free trial: \(weekly.label)")
        }
    }

    private func card(named plan: String) -> XCUIElement {
        self.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", plan)).firstMatch
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: self.app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    // MARK: - Getting there

    /// Into the editor the way a person gets there: from the archive, on a
    /// document. (`debugOpenEditor` cannot be used here — on a fresh install it
    /// races the first load and does nothing.)
    private func openTheFirstDocument() {
        let card = self.app.buttons["Meeting notes.pdf"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the seeded archive never appeared")
        self.tap(card)

        // On a phone the card opens the editor outright, and this returns here.
        // In the desktop split — Mac, and an iPad in three columns — a card only
        // fills the *detail* column with a preview, and the editor is one press
        // further: the Edit button in that column's toolbar. Without this the
        // whole bundle fails on Mac at "the document did not open", which reads
        // like a broken archive and is only a different shape.
        if self.editorBar.buttons["Tools"].waitForExistence(timeout: 5) { return }
        self.tap(self.app.buttons["Edit"].firstMatch)

        XCTAssertTrue(self.editorIsShowing, "the document did not open")
    }

    /// Opens the panel and taps a tool's tile, scrolling the grid to it if it
    /// starts below the fold — the panel holds sixteen tiles and a phone shows
    /// about eight.
    private func openFromPanel(_ tool: String, searchingFor query: String) {
        let wrench = self.editorBar.buttons["Tools"]
        XCTAssertTrue(wrench.waitForExistence(timeout: 10), "the tool panel button is missing")
        self.tap(wrench)
        XCTAssertTrue(self.app.searchFields["Search tools"].waitForExistence(timeout: 10),
                      "the tool panel did not open")

        let tile = self.app.buttons["editorTool.\(tool)"]
        guard tile.waitForExistence(timeout: 10) else {
            // Not in the tree at all, because the grid is lazy and this tile is
            // below the fold. On a phone the drag further down brings it into
            // being; on Mac it cannot, and this is not a broken panel. The sheet
            // there is a small box in the middle of a large window — about five
            // tiles of sixteen — and the drag below is normalised to the
            // *window*, so it starts outside the panel and scrolls nothing.
            // The panel's own search reaches any tile on either shape.
            return self.pickBySearching(tool, query: query)
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

    /// The panel's grid is lazy, so the tools at the bottom of it — Share is the
    /// last one — do not exist in the tree until something brings them up. The
    /// panel's own search is that something, and it is also how a person with a
    /// long list finds a tool.
    private func openFromPanelBySearching(_ tool: String, query: String) {
        let wrench = self.editorBar.buttons["Tools"]
        XCTAssertTrue(wrench.waitForExistence(timeout: 10), "the tool panel button is missing")
        self.tap(wrench)
        XCTAssertTrue(self.app.searchFields["Search tools"].waitForExistence(timeout: 10),
                      "the tool panel did not open")
        self.pickBySearching(tool, query: query)
    }

    /// Types into the panel's search and taps what comes back. The panel is
    /// already open.
    private func pickBySearching(_ tool: String, query: String) {
        let search = self.app.searchFields["Search tools"]
        self.tap(search)
        search.typeText(query)

        let tile = self.app.buttons["editorTool.\(tool)"]
        guard tile.waitForExistence(timeout: 10) else {
            print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            return XCTFail("searching for \(query) did not find \(tool)")
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
        if bar.waitForExistence(timeout: 5) {
            // Aimed at the chevron, not the middle: the back button is as wide as
            // the title it carries, and its centre sits over the editor's own title
            // menu on the screen underneath.
            let back = bar.buttons.element(boundBy: 0)
            back.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()
            return
        }
        // Mac: the tool's bar is the window's toolbar, whose leading item is a
        // plain "Back" button — narrow, and safe to hit in the middle.
        self.tap(self.app.buttons["Back"].firstMatch)
    }

    /// A tool's screen, recognised by its title. On a phone the title sits in a
    /// navigation bar; on Mac Catalyst it becomes the *window's* own title, and
    /// there is no navigation bar to find.
    private func screenIsShowing(_ title: String) -> Bool {
        if self.app.navigationBars[title].waitForExistence(timeout: 10) { return true }
        return self.app.windows[title].exists
    }

    /// Above the panel's floating search field, which overlaps the last row of
    /// tiles.
    private var panelSafeBottom: CGFloat {
        self.app.windows.firstMatch.frame.maxY - 110
    }

    /// The editor's own bar, titled with the document.
    ///
    /// On Mac Catalyst there is no such navigation bar: the same items are
    /// hoisted into the *window's* toolbar, several groups deep, and asking for
    /// a navigation bar there finds the archive's one behind the editor — or
    /// nothing. Scoping to the toolbar instead keeps every `editorBar.buttons`
    /// lookup in this file working on both shapes.
    private var editorBar: XCUIElement {
        let bar = self.app.navigationBars["Meeting notes.pdf"]
        return bar.exists ? bar : self.app.toolbars.firstMatch
    }

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
