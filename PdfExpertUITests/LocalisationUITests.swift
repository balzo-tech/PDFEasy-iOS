//
//  LocalisationUITests.swift
//  PdfExpertUITests
//
//  Section 10 of the device checklist, run here instead of by hand: what the app
//  says in Italian and in Spanish, and whether it still says it after a relaunch.
//
//  Two things a simulator can check that a person would rather not: that a screen
//  is translated *at all* (a literal `String` reaches `Text` verbatim and stays
//  English in every language — it has happened twice), and that the numbers inside
//  a sentence come out in the right order. What it cannot check is whether a long
//  Spanish label fits its button: the screenshots each test attaches are for that,
//  and they are meant to be looked at.
//
//  `XCUIElement.tap()` does not fire on this app's SwiftUI buttons — see the note
//  at the top of `EditorNavigationUITests`.
//

import XCTest

final class LocalisationUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    private func launch(language: String, onboardingShown: Bool = true, premium: Bool = true) {
        self.app.launchArguments = ["-AppleLanguages", "(\(language))",
                                    "-AppleLocale", language,
                                    "-onboardingShown", onboardingShown ? "YES" : "NO",
                                    "-debugSeedArchive", "YES"]
        if premium {
            self.app.launchArguments += ["-debugPremium", "YES"]
        }
        self.app.launch()
    }

    // MARK: - Italian

    /// The sheet that used to be English in every language.
    func testTheSignatureSheetSpeaksItalian() {
        self.launch(language: "it")
        self.openTheFirstDocument()
        self.tap(self.app.buttons["Firma PDF"].firstMatch)
        // "Finish" — that button was English in every language until 2026-07-31.
        XCTAssertTrue(self.app.buttons["Fine"].firstMatch.waitForExistence(timeout: 15),
                      "la schermata della firma non si è aperta, o il suo bottone non è tradotto")

        self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()

        XCTAssertTrue(self.app.staticTexts["Aggiungi firma"].waitForExistence(timeout: 15),
                      "il foglio della firma non è arrivato")
        for tab in ["Disegno", "Da immagine", "Da fotocamera"] {
            XCTAssertTrue(self.app.buttons[tab].firstMatch.exists, "manca il tab «\(tab)»")
        }
        self.attach("foglio-firma-it")
    }

    /// A sentence with a number in it: "1 di 3", not "1 of 3" and not "di 1 3".
    func testTheNumbersInsideItalianSentencesComeOutInOrder() {
        self.launch(language: "it")
        self.openTheFirstDocument()

        // The page counter under the document: three pages in the seeded file.
        let counter = self.app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "\\d+ di \\d+")
        ).firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 15),
                      "il contatore delle pagine non dice «1 di 3»")
        self.attach("contatore-pagine-it")
    }

    /// The very first screen, which carries the app's own name inside a sentence.
    func testTheWelcomeScreenNamesTheAppInItalian() {
        self.launch(language: "it", onboardingShown: false)
        let welcome = self.app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Benvenuto in PDF Pro'")
        ).firstMatch
        XCTAssertTrue(welcome.waitForExistence(timeout: 30),
                      "la schermata di benvenuto non nomina PDF Pro in italiano")
        self.attach("benvenuto-it")
    }

    /// The theme is an `@AppStorage` preference, so what matters on screen is that
    /// it reaches every corner — sheets and pushed tools included — and that it is
    /// still there after the app has been killed. It is set the way the app itself
    /// stores it and then read back from the running app, because driving a menu
    /// picker through XCTest tests the menu, not the theme.
    func testAlwaysLightReachesTheWholeAppAndOutlivesIt() {
        self.app.launchArguments = ["-AppleLanguages", "(it)",
                                    "-onboardingShown", "YES",
                                    "-debugSeedArchive", "YES",
                                    "-debugPremium", "YES",
                                    "-appTheme", "light"]
        self.app.launch()
        self.openSettings()
        // Whether the screen is *light* is not something XCTest can read: the
        // screenshot is the evidence, and it is meant to be looked at.
        self.attach("impostazioni-tema-chiaro")

        // And it is still light on the way back out, on a screen that is not this
        // one — the theme is applied at the root so it reaches sheets and covers.
        self.app.terminate()
        self.app.launch()
        self.openTheFirstDocument()
        self.attach("editor-tema-chiaro")
        XCTAssertTrue(self.app.navigationBars["Meeting notes.pdf"].exists,
                      "il documento non si è aperto dopo il riavvio")
    }

    /// A signature is drawn in black on white, and that has to hold when the app
    /// itself is light: the sheet paints its own background so the ink cannot end
    /// up black on black. Drawn for real — a stroke on the canvas — because the
    /// only proof that the ink landed is Confirm coming on.
    func testASignatureDrawnWithTheAppInLightThemeIsBlackOnWhite() {
        self.app.launchArguments = ["-AppleLanguages", "(it)",
                                    "-onboardingShown", "YES",
                                    "-debugSeedArchive", "YES",
                                    "-debugPremium", "YES",
                                    "-appTheme", "light"]
        self.app.launch()
        self.openTheFirstDocument()
        self.tap(self.app.buttons["Firma PDF"].firstMatch)
        XCTAssertTrue(self.app.buttons["Fine"].firstMatch.waitForExistence(timeout: 15))
        self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertTrue(self.app.staticTexts["Aggiungi firma"].waitForExistence(timeout: 15))

        let confirm = self.app.buttons["Conferma"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertFalse(confirm.isEnabled, "si può confermare una firma che non c'è")

        // A stroke across the canvas, which is the band between the three tabs and
        // the "Firma qui" line — about half way down the screen, not down in the
        // sheet's lower half where the buttons are.
        let canvas = self.app.staticTexts["Firma qui"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "il foglio non mostra «Firma qui»")
        let above = canvas.frame.minY - 30
        let window = self.app.windows.firstMatch.frame
        let start = self.app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.width * 0.3, dy: above))
        let end = self.app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.width * 0.7, dy: above - 20))
        start.press(forDuration: 0.1, thenDragTo: end)

        self.attach("firma-tema-chiaro")
        XCTAssertTrue(confirm.isEnabled, "il tratto non è arrivato sulla tela")
    }

    /// The sheet that offers where to take a document from. Every one of these
    /// labels was English in every language until 2026-07-31.
    func testTheImportSheetSpeaksItalian() {
        self.launch(language: "it")
        // From the tools tab, a tool that needs a document asks where it comes from.
        self.tap(self.app.buttons["Strumenti"].firstMatch)
        self.tap(self.app.buttons["Firma PDF"].firstMatch)

        guard self.app.staticTexts["Importa da"].waitForExistence(timeout: 15) else {
            print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            return XCTFail("il menu «Importa da» non è arrivato")
        }
        for option in ["File", "Scansiona un documento"] {
            XCTAssertTrue(self.app.buttons[option].firstMatch.exists ||
                          self.app.staticTexts[option].firstMatch.exists,
                          "manca la voce «\(option)»")
        }
        self.attach("importa-da-it")
    }

    private func openSettings() {
        self.tap(self.app.buttons["Impostazioni"].firstMatch)
        XCTAssertTrue(self.app.staticTexts["Aspetto"].waitForExistence(timeout: 15),
                      "le impostazioni non si sono aperte")
    }


    // MARK: - Spanish

    /// Spanish runs long — "Comprimir PDF", "Desde la cámara", "Prueba gratuita" —
    /// and the screens that hold the most words are the ones to look at.
    func testTheLongSpanishLabelsHaveSomewhereToFit() {
        self.launch(language: "es")
        self.openTheFirstDocument()

        self.openFromPanelBySearching("compress", query: "Comprimir")
        XCTAssertTrue(self.app.navigationBars["Comprimir PDF"].waitForExistence(timeout: 15),
                      "la compresión no se abrió en español")
        self.attach("compressione-es")
    }

    func testThePaywallIsInSpanishForANonSubscriber() {
        self.launch(language: "es", premium: false)
        self.openTheFirstDocument()
        self.openFromPanelBySearching("share", query: "Compartir")

        let paywall = self.app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'gratis' OR label CONTAINS[c] 'gratuita'")
        ).firstMatch
        guard paywall.waitForExistence(timeout: 20) else {
            print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            return XCTFail("el muro de pago no apareció en español")
        }
        self.attach("paywall-es")
    }

    // MARK: - Getting there

    private func openTheFirstDocument() {
        let card = self.app.buttons["Meeting notes.pdf"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "l'archivio di prova non è arrivato")
        self.tap(card)
        XCTAssertTrue(self.app.navigationBars["Meeting notes.pdf"].waitForExistence(timeout: 15),
                      "il documento non si è aperto")
    }

    /// The panel's grid is lazy, so a tool below the fold is not in the tree until
    /// the search brings it up.
    private func openFromPanelBySearching(_ tool: String, query: String) {
        let wrench = self.app.navigationBars["Meeting notes.pdf"].buttons["Herramientas"]
        self.tap(wrench)
        // The panel's own search field, not the archive's behind it: both are in
        // the tree, and `firstMatch` picks the wrong one.
        let search = self.app.searchFields["Buscar herramientas"]
        XCTAssertTrue(search.waitForExistence(timeout: 15), "il pannello degli strumenti non si è aperto")
        self.tap(search)
        // A tap is not focus: the field has to be first responder before typing.
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.typeText(query)

        let tile = self.app.buttons["editorTool.\(tool)"]
        guard tile.waitForExistence(timeout: 15) else {
            print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            return XCTFail("\(query) non ha trovato \(tool)")
        }
        self.tap(tile)
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: self.app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) non è mai comparso", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
