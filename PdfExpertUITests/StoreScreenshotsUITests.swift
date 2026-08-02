//
//  StoreScreenshotsUITests.swift
//  PdfExpertUITests
//
//  The six screens that go on the App Store page.
//
//  Not a test of anything: it drives the app to each screen and photographs it,
//  so the store shots are the app as it actually is on the day they are made,
//  and can be remade in one command when a screen changes. The pictures come out
//  as attachments in the result bundle; `tools/store-screenshots.sh` pulls them
//  out and drops them where the layout expects them.
//
//  Taps go through `tap(_:)` for the reason written at the top of
//  `EditorNavigationUITests`: `XCUIElement.tap()` never fires in this app,
//  because our SwiftUI buttons report `isHittable = false`.
//
//  One screen is missing on purpose. The scanner's camera is a black rectangle
//  in the simulator, so shot 1 is the scanner *home* — the screen a person meets
//  before the camera opens. A camera shot has to come off a real device.
//

import XCTest

final class StoreScreenshotsUITests: XCTestCase {

    private var app: XCUIApplication!

    /// The tabs are reached by tapping the bar, not by `debugInitialTab`: that
    /// flag sets the tab in the coordinator's `init`, and something downstream
    /// puts it back on Files before the screen settles — the first run of this
    /// bundle photographed the archive three times over.
    private enum Tab: String {
        case files = "Files", tools = "Tools", chat = "ChatPDF", scanner = "Scanner"
    }

    override func setUpWithError() throws {
        self.continueAfterFailure = false
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    // MARK: - The six shots

    func testTakesTheStoreScreenshots() {
        // 1 — scanning, which is what people search for. The camera itself is a
        // black rectangle in the simulator, so this is the review screen that
        // follows it: `debugStartScan` opens the flow and `debugScanPages` fills
        // it with pages, which is the only way to see it without a camera.
        self.launch(extraArguments: ["-debugStartScan", "YES", "-debugScanPages", "YES"])
        self.settle()
        self.shoot("01-scan")

        // 2 — the tool catalog: "this app converts anything".
        self.launch()
        self.show(.tools)
        self.settle()
        self.shoot("02-convert")

        // 4 — the editor's tool panel. Taken before the signature because
        // getting there is the same journey, minus one step.
        self.launch()
        self.openTheFirstDocument()
        self.openToolPanel()
        self.settle()
        self.shoot("04-edit")

        // 3 — the signature, actually on the page. Not in the panel: signing is
        // one of the four edits that live in the bar under the page.
        self.launch()
        self.openTheFirstDocument()
        self.tap(self.app.buttons["Sign PDF"].firstMatch)
        self.drawASignature()
        self.settle()
        self.shoot("03-sign")

        // 5 — the password sheet, from a fresh editor.
        self.launch()
        self.openTheFirstDocument()
        self.openToolPanel()
        self.tapTile("password", searchingFor: "Password")
        self.settle()
        self.shoot("05-protect")

    }

    /// The sixth shot, which only comes out on a device.
    ///
    /// ChatPDF goes through the proxy, and the proxy wants the subscription's
    /// `originalTransactionId` from StoreKit before it answers anything. A
    /// simulator has no such transaction — `-debugPremium` opens the app's own
    /// gates but cannot invent one — so there the conversation stops at "This
    /// feature is part of the subscription". Run this one against a phone with a
    /// live subscription:
    ///
    ///   xcodebuild test -destination 'platform=iOS,name=<device>' \
    ///     -only-testing:PdfExpertUITests/StoreScreenshotsUITests/testTakesTheChatScreenshot
    func testTakesTheChatScreenshot() {
        self.launch(extraArguments: ["-debugChatWithArchive", "YES"])
        self.show(.chat)
        // With the flag on, this button starts the conversation on the bundled
        // test document instead of opening the import sheet.
        self.tap(self.app.buttons["Choose a PDF"].firstMatch)
        self.ask("What is this document about?")
        self.settle()
        self.shoot("06-ask")
    }

    // MARK: - Signing

    /// Draws a signature and puts it on the page: tap the page, pick Drawing,
    /// scribble on the PencilKit canvas, confirm. Four strokes rather than one
    /// line — a single drag draws a stroke as straight as a ruler, which is not
    /// what a signature looks like.
    private func drawASignature() {
        XCTAssertTrue(self.app.buttons["Finish"].firstMatch.waitForExistence(timeout: 15),
                      "the signature screen did not open")
        self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap()

        XCTAssertTrue(self.app.staticTexts["Add Signature"].waitForExistence(timeout: 15),
                      "tapping the page did not open the signature sheet")
        self.tap(self.app.buttons["Drawing"].firstMatch)

        let confirm = self.app.buttons["Confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 15), "the drawing canvas did not open")

        // Anchored to the "Sign in here" caption that sits directly under the
        // canvas, not to Confirm: between the two there are the "Memorize
        // signature" toggle and two spacers, and drawing there draws nothing.
        let caption = self.app.staticTexts["Sign in here"].firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 10), "the drawing canvas is not showing")
        let canvasBottom = caption.frame.minY - 10
        let canvasTop = canvasBottom - 96
        let left = confirm.frame.minX + 40
        let width = confirm.frame.width - 110

        func point(_ dx: CGFloat, _ dy: CGFloat) -> XCUICoordinate {
            self.app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: left + width * dx,
                                     dy: canvasBottom - (canvasBottom - canvasTop) * dy))
        }

        // Short segments rather than long ones: each drag draws a straight line,
        // and a signature made of four long lines looks like a lightning bolt.
        let strokes: [[(CGFloat, CGFloat)]] = [
            [(0.02, 0.30), (0.06, 0.70), (0.10, 0.78), (0.14, 0.55),
             (0.17, 0.30), (0.20, 0.48), (0.24, 0.66), (0.28, 0.52)],
            [(0.32, 0.40), (0.36, 0.62), (0.40, 0.70), (0.44, 0.50),
             (0.48, 0.34), (0.52, 0.52), (0.56, 0.64)],
            [(0.60, 0.58), (0.65, 0.36), (0.70, 0.56), (0.75, 0.66),
             (0.80, 0.48), (0.86, 0.40), (0.94, 0.46)],
        ]
        for stroke in strokes {
            for (from, to) in zip(stroke, stroke.dropFirst()) {
                point(from.0, from.1).press(forDuration: 0.04, thenDragTo: point(to.0, to.1))
            }
        }

        XCTAssertTrue(confirm.isEnabled, "the canvas did not register the drawing")
        self.tap(confirm)

        // Finish puts the signature into the document. Without it the shot shows
        // the signature still selected, inside its resize handles.
        self.tap(self.app.buttons["Finish"].firstMatch)
    }

    // MARK: - ChatPDF

    /// Types a question and waits for the answer to come back from the service.
    ///
    /// The document arrives through `debugChatWithArchive`, not through the
    /// screen's own two ways in: the file picker cannot be driven from a test,
    /// and the scanner hands over photographed pages, which carry no extractable
    /// text — the chat answers that with "Try Make Searchable (OCR) first".
    private func ask(_ question: String) {
        // `TextField(axis: .vertical)` reaches the tree as a text view, not a
        // text field, and which of the two it is has changed between releases —
        // so both are accepted.
        let asView = self.app.textViews["Type your Message..."].firstMatch
        let asField = self.app.textFields["Type your Message..."].firstMatch
        let field: XCUIElement
        if asView.waitForExistence(timeout: 90) {
            field = asView
        } else if asField.exists {
            field = asField
        } else {
            // Not a failure worth stopping on: the picture is still taken, and
            // the tree tells us where the flow actually stopped.
            print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            self.shoot("90-chat-stopped-here")
            return
        }
        self.tap(field)
        field.typeText(question)

        // The send button is the one next to the field; it only enables once
        // there is something to send.
        let send = self.app.buttons.matching(NSPredicate(format: "isEnabled == true"))
            .allElementsBoundByIndex
            .last { $0.frame.minY > field.frame.minY - 40 }
        if let send { self.tap(send) }

        // The reply arrives over the network: wait for the question to stop
        // being the last thing on screen.
        let answered = NSPredicate(format: "count > 0")
        let replies = self.app.staticTexts.matching(NSPredicate(
            format: "NOT (label CONTAINS[c] %@) AND NOT (label CONTAINS[c] %@)",
            question, "Type your Message"))
        self.expectation(for: answered, evaluatedWith: replies)
        self.waitForExpectations(timeout: 120)
    }

    // MARK: - Getting there

    /// A fresh install every time, so the archive is seeded, onboarding is out
    /// of the way, premium is on (no paywall in the picture) and the language is
    /// English — the store page these go on is the US one.
    private func launch(extraArguments: [String] = []) {
        // Five of the six are taken on a simulator that is in light mode; the
        // phone this runs on for the sixth may not be, and a dark shot among
        // five light ones looks like a mistake on the store page.
        XCUIDevice.shared.appearance = .light
        self.app = XCUIApplication()
        self.app.launchArguments = ["-AppleLanguages", "(en)",
                                    "-onboardingShown", "YES",
                                    "-debugSeedArchive", "YES",
                                    "-debugPremium", "YES"] + extraArguments
        self.app.launch()
    }

    /// The tab bar on a phone; on the desktop split the same sections are rows
    /// in the sidebar, which answer to the same labels.
    private func show(_ tab: Tab) {
        let bar = self.app.tabBars.firstMatch
        let inBar = bar.buttons[tab.rawValue]
        self.tap(inBar.waitForExistence(timeout: 10) ? inBar
                                                     : self.app.buttons[tab.rawValue].firstMatch)
    }

    private func openTheFirstDocument() {
        let card = self.app.buttons["Meeting notes.pdf"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the seeded archive never appeared")
        self.tap(card)

        if self.editorBar.buttons["Tools"].waitForExistence(timeout: 5) { return }
        self.tap(self.app.buttons["Edit"].firstMatch)   // desktop split: one press further
    }

    private func openToolPanel() {
        let wrench = self.editorBar.buttons["Tools"]
        XCTAssertTrue(wrench.waitForExistence(timeout: 15), "the tool panel button is missing")
        self.tap(wrench)
        XCTAssertTrue(self.app.searchFields["Search tools"].waitForExistence(timeout: 15),
                      "the tool panel did not open")
    }

    /// Taps a tile in the open panel, reaching for the panel's search when the
    /// tile is below the fold — the grid is lazy, so a tile down there is not in
    /// the tree at all until something brings it up.
    private func tapTile(_ tool: String, searchingFor query: String? = nil) {
        let tile = self.app.buttons["editorTool.\(tool)"]
        if tile.waitForExistence(timeout: 10) {
            self.tap(tile)
            return
        }
        guard let query else {
            return XCTFail("\(tool) is not in the panel and no search term was given")
        }
        let search = self.app.searchFields["Search tools"]
        self.tap(search)
        search.typeText(query)
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "searching for \(query) did not find \(tool)")
        self.tap(tile)
    }

    private var editorBar: XCUIElement {
        let bar = self.app.navigationBars["Meeting notes.pdf"]
        return bar.exists ? bar : self.app.toolbars.firstMatch
    }

    // MARK: - Taking the picture

    /// Long enough for the glass bars to finish settling and any thumbnail to
    /// finish drawing. A screenshot taken mid-animation looks like a bug.
    private func settle() {
        Thread.sleep(forTimeInterval: 2.5)
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        self.add(shot)
    }

    /// See `EditorNavigationUITests`: `tap()` waits for hittability that never
    /// arrives, so every tap here is synthesised at the centre of the frame.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            return XCTFail("\(element) never appeared", file: file, line: line)
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
