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
    ///
    /// The raw values are the English labels; `show(_:)` translates them.
    private enum Tab: String {
        case files = "Files", tools = "Tools", chat = "ChatPDF", scanner = "Scanner"
    }

    // MARK: - Which language we are photographing

    /// One of the app's three languages, chosen from the environment:
    ///
    ///     TEST_RUNNER_SHOT_LANG=it xcodebuild test …
    ///
    /// The `TEST_RUNNER_` prefix is how xcodebuild hands a variable to the test
    /// process; it arrives here without it.
    ///
    /// The store page exists in fourteen languages but the app is translated
    /// into three, so three sets of pictures is all there is to take; the other
    /// eleven pages fall back to the English set.
    private var language: String {
        ProcessInfo.processInfo.environment["SHOT_LANG"] ?? "en"
    }

    /// The labels this file navigates by, in the two languages that are not
    /// English.
    ///
    /// Copied from `Localizable.xcstrings` rather than read out of it: a test
    /// bundle cannot see the app's catalogue at runtime. The cost is that a
    /// translation changed in the catalogue and not here makes the run fail —
    /// which is the right failure, because the alternative is photographing
    /// whatever screen the app happened to land on.
    private static let labels: [String: [String: String]] = [
        "Files":                ["it": "File",                      "es": "Archivos"],
        "Tools":                ["it": "Strumenti",                 "es": "Herramientas"],
        "Scanner":              ["it": "Scanner",                   "es": "Escáner"],
        "Sign PDF":             ["it": "Firma PDF",                 "es": "Firmar PDF"],
        "Choose a PDF":         ["it": "Scegli un PDF",             "es": "Elige un PDF"],
        "Add Signature":        ["it": "Aggiungi firma",            "es": "Añadir firma"],
        "Drawing":              ["it": "Disegno",                   "es": "Dibujo"],
        "Confirm":              ["it": "Conferma",                  "es": "Confirmar"],
        "Finish":               ["it": "Fine",                      "es": "Finalizar"],
        "Sign in here":         ["it": "Firma qui",                 "es": "Firma aquí"],
        "Search tools":         ["it": "Cerca strumenti",           "es": "Buscar herramientas"],
        "Type your Message...": ["it": "Scrivi il tuo messaggio...", "es": "Escribe tu mensaje..."],
        "Edit":                 ["it": "Modifica",                  "es": "Editar"],
        "Password":             ["it": "Password",                  "es": "Contraseña"],
        "Tap where you wish to sign": ["it": "Tocca dove vuoi firmare",
                                       "es": "Toca donde quieras firmar"],
    ]

    /// The document the screenshots are taken over: a lease agreement, seeded
    /// at the top of the archive, named in the language it is written in. It
    /// shows in the editor's title bar, so it has to match what the app saved.
    private var contract: String {
        switch self.language {
        case "it": return "Contratto di locazione.pdf"
        case "es": return "Contrato de arrendamiento.pdf"
        default:   return "Rental agreement.pdf"
        }
    }

    /// The question the chat answers, asked in the language of the run. The
    /// answer comes back in whatever language it was asked in, which is the
    /// whole point of taking this shot three times.
    private static let chatQuestions = [
        "en": "What is this document about?",
        "it": "Di cosa parla questo documento?",
        "es": "¿De qué trata este documento?",
    ]

    /// English in, the running language out. Words that are the same in all
    /// three — "ChatPDF" — are not in the table and come back untouched.
    private func t(_ english: String) -> String {
        guard self.language != "en" else { return english }
        return Self.labels[english]?[self.language] ?? english
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
        self.tap(self.app.buttons[self.t("Sign PDF")].firstMatch)
        self.drawASignature()
        self.settle()
        self.shoot("03-sign")

        // 5 — the password sheet, from a fresh editor.
        self.launch()
        self.openTheFirstDocument()
        self.openToolPanel()
        self.tapTile("password", searchingFor: self.t("Password"))
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
        self.tap(self.app.buttons[self.t("Choose a PDF")].firstMatch)
        self.ask(Self.chatQuestions[self.language] ?? Self.chatQuestions["en"]!)
        self.settle()
        self.shoot("06-ask")
    }

    // MARK: - Signing

    /// Draws a signature and puts it on the page: tap the page, pick Drawing,
    /// scribble on the PencilKit canvas, confirm. Four strokes rather than one
    /// line — a single drag draws a stroke as straight as a ruler, which is not
    /// what a signature looks like.
    private func drawASignature() {
        XCTAssertTrue(self.app.buttons[self.t("Finish")].firstMatch.waitForExistence(timeout: 15),
                      "the signature screen did not open")
        // Low on the page, in the white under the last clause. 0.42 was chosen
        // when the document was Lorem ipsum and any spot would do; on a contract
        // it put the signature straight through the rent and deposit clauses,
        // which is not where anyone signs anything.
        self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.63)).tap()

        XCTAssertTrue(self.app.staticTexts[self.t("Add Signature")].waitForExistence(timeout: 15),
                      "tapping the page did not open the signature sheet")
        self.tap(self.app.buttons[self.t("Drawing")].firstMatch)

        let confirm = self.app.buttons[self.t("Confirm")].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 15), "the drawing canvas did not open")

        // Anchored to the "Sign in here" caption that sits directly under the
        // canvas, not to Confirm: between the two there are the "Memorize
        // signature" toggle and two spacers, and drawing there draws nothing.
        let caption = self.app.staticTexts[self.t("Sign in here")].firstMatch
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
        //
        // Not `firstMatch`: four screens in this app have a button called
        // Finish — fill-widget, fill-form and suggested-fields, besides this one
        // — and they are all in the tree at once. `firstMatch` was picking one
        // of the others, which dismissed the signature screen and threw the
        // signature away: the store shot came out with a clean page and the test
        // passed, because every step had worked and nothing checked the result.
        // The one that belongs to this screen is the wide button at the bottom.
        let finish = self.app.buttons
            .matching(NSPredicate(format: "label == %@", self.t("Finish")))
            .allElementsBoundByIndex
            .max { $0.frame.minY < $1.frame.minY }
        XCTAssertNotNil(finish, "no Finish button anywhere in the tree")
        self.tap(finish!)

        // The result, not the journey: the signature screen has to be gone. It
        // is the only evidence that the signature was kept rather than dropped.
        XCTAssertTrue(self.app.staticTexts[self.t("Tap where you wish to sign")]
                        .waitForNonExistence(timeout: 10),
                      "Finish did not close the signature screen — the signature was discarded")
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
        let placeholder = self.t("Type your Message...")
        let asView = self.app.textViews[placeholder].firstMatch
        let asField = self.app.textFields[placeholder].firstMatch
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
            question, placeholder))
        self.expectation(for: answered, evaluatedWith: replies)
        self.waitForExpectations(timeout: 120)
    }

    // MARK: - Getting there

    /// A fresh install every time, so the archive is seeded, onboarding is out
    /// of the way, premium is on (no paywall in the picture) and the app speaks
    /// the language this run is photographing.
    private func launch(extraArguments: [String] = []) {
        // The phone this runs on may be in dark mode, and one dark shot among
        // five light ones looks like a mistake on the store page.
        XCUIDevice.shared.appearance = .light
        self.app = XCUIApplication()
        // `debugResetArchive` matters here more than anywhere else: a UI test
        // installs the app fresh but keeps the container, and the seed skips a
        // non-empty archive. Without it the Italian run opened the English
        // archive left behind by the run before — same five documents, wrong
        // language, and the contract in the picture would have been the wrong
        // one.
        self.app.launchArguments = ["-AppleLanguages", "(\(self.language))",
                                    "-AppleLocale", self.language,
                                    "-onboardingShown", "YES",
                                    "-debugSeedArchive", "YES",
                                    "-debugResetArchive", "YES",
                                    "-debugPremium", "YES"] + extraArguments
        self.app.launch()
    }

    /// The tab bar on a phone; on the desktop split the same sections are rows
    /// in the sidebar, which answer to the same labels.
    private func show(_ tab: Tab) {
        let name = self.t(tab.rawValue)
        let bar = self.app.tabBars.firstMatch
        let inBar = bar.buttons[name]
        self.tap(inBar.waitForExistence(timeout: 10) ? inBar
                                                     : self.app.buttons[name].firstMatch)
    }

    private func openTheFirstDocument() {
        let card = self.app.buttons[self.contract].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the seeded archive never appeared")
        self.tap(card)

        // The editor is open when its own bar, titled with the file name, shows
        // up. Not the tool button: in some languages that button is not there at
        // all, folded into the overflow menu — see `openToolPanel`.
        if self.app.navigationBars[self.contract].waitForExistence(timeout: 8) { return }
        self.tap(self.app.buttons[self.t("Edit")].firstMatch)   // desktop split: one press further
    }

    /// The wrench that opens the tool panel, when it is on screen at all.
    ///
    /// Two buttons answer to this name and only one of them is the wrench: the
    /// Tools *tab* sits at the bottom and stays in the tree behind the open
    /// document, so anything that matches by name alone eventually presses the
    /// tab and leaves the editor. The wrench lives in the bar at the top, hence
    /// the cut-off.
    private var toolButton: XCUIElement? {
        self.app.buttons
            .matching(NSPredicate(format: "label == %@", self.t("Tools")))
            .allElementsBoundByIndex
            .first { $0.frame.minY < 200 }
    }

    /// Opens the tool panel, going through the overflow menu when the bar has
    /// folded the wrench into it.
    ///
    /// Italian and Spanish labels are longer than the English ones, the editor's
    /// bar runs out of room, and the toolbar collapses what does not fit into an
    /// "Altro" menu. So the wrench is a button in English and a row in a menu in
    /// the other two — the same screen, reached two different ways, and the
    /// reason this test only ever failed in the languages nobody ran first.
    private func openToolPanel() {
        if let wrench = self.toolButton {
            self.tap(wrench)
        } else {
            let overflow = self.app.buttons["OverflowBarButtonItem"].firstMatch
            XCTAssertTrue(overflow.waitForExistence(timeout: 10),
                          "neither the tool button nor the overflow menu is on screen")
            self.tap(overflow)

            let inMenu = self.app.buttons[self.t("Tools")].firstMatch
            XCTAssertTrue(inMenu.waitForExistence(timeout: 10),
                          "the overflow menu opened but has no tool row")
            self.tap(inMenu)
        }
        XCTAssertTrue(self.app.searchFields[self.t("Search tools")].waitForExistence(timeout: 15),
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
        let search = self.app.searchFields[self.t("Search tools")]
        self.tap(search)
        search.typeText(query)
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "searching for \(query) did not find \(tool)")
        self.tap(tile)
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
