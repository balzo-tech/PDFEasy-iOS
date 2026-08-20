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
        "Files":                ["it": "File",                      "es": "Archivos", "de": "Dateien", "fr": "Fichiers"],
        "Tools":                ["it": "Strumenti",                 "es": "Herramientas", "de": "Werkzeuge", "fr": "Outils"],
        "Scanner":              ["it": "Scanner",                   "es": "Escáner", "de": "Scanner", "fr": "Scanner"],
        "Sign PDF":             ["it": "Firma PDF",                 "es": "Firmar PDF", "de": "PDF unterschreiben", "fr": "Signer le PDF"],
        "Choose a PDF":         ["it": "Scegli un PDF",             "es": "Elige un PDF", "de": "Ein PDF wählen", "fr": "Choisir un PDF"],
        "Finish":               ["it": "Fine",                      "es": "Finalizar", "de": "Abschließen", "fr": "Terminer"],
        "Search tools":         ["it": "Cerca strumenti",           "es": "Buscar herramientas", "de": "Werkzeuge suchen", "fr": "Rechercher des outils"],
        "Type your Message...": ["it": "Scrivi il tuo messaggio...", "es": "Escribe tu mensaje...", "de": "Schreiben Sie Ihre Nachricht...", "fr": "Écrivez votre message..."],
        "Edit":                 ["it": "Modifica",                  "es": "Editar", "de": "Bearbeiten", "fr": "Modifier"],
        "Password":             ["it": "Password",                  "es": "Contraseña", "de": "Passwort", "fr": "Mot de passe"],
        "Your Signatures":      ["it": "Le tue firme",              "es": "Tus firmas", "de": "Ihre Unterschriften", "fr": "Vos signatures"],
        "Tap where you wish to sign": ["it": "Tocca dove vuoi firmare",
                                       "es": "Toca donde quieras firmar",
                                       "de": "Tippen Sie dorthin, wo Sie unterschreiben möchten",
                                       "fr": "Touchez l'endroit où vous voulez signer"],
    ]

    /// The document the screenshots are taken over: a lease agreement, seeded
    /// at the top of the archive, named in the language it is written in. It
    /// shows in the editor's title bar, so it has to match what the app saved.
    private var contract: String {
        switch self.language {
        case "it": return "Contratto di locazione.pdf"
        case "es": return "Contrato de arrendamiento.pdf"
        case "de": return "Mietvertrag.pdf"
        case "fr": return "Contrat de location.pdf"
        default:   return "Rental agreement.pdf"
        }
    }

    /// The tenant of the lease, in the language of the run: the name the seeded
    /// signature is written in. A German lease signed "Daniele Marchi" is the
    /// kind of detail nobody notices until it is on the store page.
    private var signatory: String {
        switch self.language {
        case "it": return "Daniele Marchi"
        case "es": return "Daniel Marchena"
        case "de": return "Daniel Markwart"
        case "fr": return "Daniel Marchand"
        default:   return "Daniel R. Marsh"
        }
    }

    /// The question the chat answers, asked in the language of the run. The
    /// answer comes back in whatever language it was asked in, which is the
    /// whole point of taking this shot three times.
    private static let chatQuestions = [
        "en": "What is this document about?",
        "it": "Di cosa parla questo documento?",
        "es": "¿De qué trata este documento?",
        "de": "Worum geht es in diesem Dokument?",
        "fr": "De quoi parle ce document ?",
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
        self.signTheContract()
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

    /// Signs the contract: tap the page, then take the signature the app already
    /// has.
    ///
    /// It has one because the app was launched with `-debugSeedSignature`, and
    /// that is the whole trick. Drawing one from here means synthesized drags,
    /// and a drag draws a straight segment: the last attempt sampled three
    /// curves and still came out as a scribble laid across the rent clause,
    /// next to Italian and Spanish slides carrying a real signature. A saved one
    /// is written in Snell Roundhand, reads as a name, and is identical in every
    /// language — and picking it is what the slide promises anyway: draw it
    /// once, reuse it on every file.
    private func signTheContract() {
        XCTAssertTrue(self.app.buttons[self.t("Finish")].firstMatch.waitForExistence(timeout: 15),
                      "the signature screen did not open")
        // Low on the page, in the white under the last clause.
        //
        // Not as low as a contract is actually signed, and on the phone that is
        // not the tap: the editor opens fitted to the width, so the signing
        // lines at the foot of the page are not on screen at all, and neither
        // `swipeUp` nor `pinch` moves the PDF view — the synthesized gestures do
        // not reach it. On the iPad the whole page is visible and the white
        // margin sits at 0.86, but tapping there opens nothing at all, so both
        // devices sign at 0.63 until the editor can be opened fitted to the page.
        // Nothing scrolls the PDF view from a test — not `swipeUp`, not a slow
        // press-and-drag, not `pinch`. The page has to fit on screen by being
        // short enough, which is why the lease is one page: its signing lines
        // are in the picture, and the signature can be put on them.
        self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.63)).tap()

        let title = self.app.staticTexts[self.t("Your Signatures")]
        XCTAssertTrue(title.waitForExistence(timeout: 15),
                      "tapping the page did not open the signature picker — was the app seeded?")

        // The saved signature is a row in a List: it comes through as a cell
        // holding an image, with no label of its own, so it has to be taken by
        // position. Not `cells.firstMatch`, though — on an iPad the archive
        // sidebar is still in the tree behind the sheet, and its first row comes
        // first: tapping it chose nothing, the picker stayed open, and Finish
        // then closed a screen that had no signature on it. The rows that belong
        // to this sheet are the ones under its title.
        let saved = self.app.cells.allElementsBoundByIndex
            .filter { $0.frame.minY > title.frame.maxY && $0.frame.width > 0 }
            .min { $0.frame.minY < $1.frame.minY }
        XCTAssertNotNil(saved, "the picker is open but the seeded signature is not in it")
        self.tap(saved!)

        // The app drops a new signature in the middle of the PDF view — the tap
        // chose the page, not the spot — so it is dragged down onto the signing
        // lines while it is still selected.
        //
        // The numbers are measured off a capture rather than reasoned about. The
        // grab is at 0.43, where the middle of the PDF view falls — the toolbar
        // under it is taller than the title bar above, so it is not the middle
        // of the screen. The drop is above the tenant's signing line and over
        // its column: dragging to (0.5, 0.66) landed the ink under the line and
        // between the two columns, which is 0.09 low and half a column left.
        // On the iPad the page is drawn beside a thumbnail rail rather than
        // across the whole width, and the toolbars take a smaller share of a
        // taller screen: both ends of the drag move.
        // The signature is a wide, shallow strip — a fifth of a page across and
        // barely 4% of the screen tall — so the grab has to be measured off a
        // capture, not reasoned about: a few points high and it takes the page
        // instead, the signature is dropped, and Finish closes on nothing.
        // Both pairs are read off a capture of the run before: where the ink
        // came out, and where the tenant's signing line is. They differ between
        // the two devices because the iPad draws the page beside a thumbnail
        // rail and gives its toolbars a smaller share of a taller screen.
        let wideScreen = self.app.frame.width / self.app.frame.height > 0.7
        let grab = wideScreen ? CGVector(dx: 0.51, dy: 0.495) : CGVector(dx: 0.50, dy: 0.43)
        let drop = wideScreen ? CGVector(dx: 0.68, dy: 0.66) : CGVector(dx: 0.68, dy: 0.57)
        self.app.coordinate(withNormalizedOffset: grab)
            .press(forDuration: 0.25,
                   thenDragTo: self.app.coordinate(withNormalizedOffset: drop))
        // The drag ends in a spring-back animation, and tapping Finish through
        // it dismissed the screen without keeping the signature.
        self.settle()

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
        // The orientation is not set from here. `XCUIDevice.shared.orientation`
        // turns the app without turning the display buffer: the capture then
        // comes out with a landscape screen drawn sideways inside a portrait
        // PNG. The simulator has to be standing up before the run instead —
        // `xcrun simctl shutdown` and boot it again puts it back.
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
                                    "-debugPremium", "YES",
                                    // A signature in the store, so the signing
                                    // shot picks a written one instead of
                                    // dragging a scribble onto the contract.
                                    "-debugSeedSignature", self.signatory] + extraArguments
        self.app.launch()
    }

    /// The tab bar on a phone; on an iPad or the desktop split the same sections
    /// are rows in the sidebar.
    ///
    /// Same labels, different kind of element: a sidebar row reaches the tree as
    /// static text, not as a button, so asking for a button by name finds
    /// nothing at all on an iPad. Three ways in, in the order they exist.
    private func show(_ tab: Tab) {
        let name = self.t(tab.rawValue)

        let inBar = self.app.tabBars.firstMatch.buttons[name]
        if inBar.waitForExistence(timeout: 10) { return self.tap(inBar) }

        let asButton = self.app.buttons[name].firstMatch
        if asButton.exists { return self.tap(asButton) }

        let asRow = self.app.staticTexts[name].firstMatch
        XCTAssertTrue(asRow.waitForExistence(timeout: 10),
                      "\(name) is neither a tab, a button nor a sidebar row")
        self.tap(asRow)
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
