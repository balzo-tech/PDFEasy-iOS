//
//  SignedDocumentToolUITests.swift
//  PdfExpertUITests
//
//  The reader for `.p7m` files has worked since it shipped, on every import
//  path, and nobody could have known: it had no name anywhere in the app. These
//  tests are about the name, not the parser — `SignedContainerUtilityTests`
//  covers the envelopes.
//
//  So what is checked here is discovery: that someone who types what they were
//  sent — the extension, "signed", "digital signature" — is offered the tool,
//  and that pressing it asks for a file. The catalog is one list shared by the
//  phone grid, the split view's middle column and Shortcuts, so a tile found
//  here is a tile everywhere.
//
//  Same tapping rule as the other UI tests: `XCUIElement.tap()` never fires in
//  this app, every touch goes through `tap(_:)`.
//

import XCTest

final class SignedDocumentToolUITests: XCTestCase {

    private var app: XCUIApplication!

    private let toolTitle = "Open signed document"

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    /// English, past the onboarding: the screens here are recognised by their
    /// titles.
    private func launch() {
        self.app.launchArguments = ["-AppleLanguages", "(en)",
                                    "-onboardingShown", "YES",
                                    "-debugPremium", "YES"]
        self.app.launch()
        self.showTools()
    }

    // MARK: - Discovery

    /// The extension is what the file is called on the user's screen, and it is
    /// what someone types into a search box. It is not in the tool's title, so
    /// this only passes because the keyword is on the tile.
    func testTheToolIsFoundBySearchingForTheExtension() {
        self.launch()
        self.search("p7m")

        XCTAssertTrue(self.app.staticTexts[self.toolTitle].waitForExistence(timeout: 10),
                      "searching the app for p7m does not offer the tool that opens one")
    }

    /// The other half of the audience: people who never learned the extension
    /// and describe what they were sent.
    func testTheToolIsFoundBySearchingForTheWords() {
        self.launch()
        self.search("signed")

        XCTAssertTrue(self.app.staticTexts[self.toolTitle].waitForExistence(timeout: 10),
                      "searching for \"signed\" does not offer the signed-document tool")
    }

    /// The tile is in the grid too, not only behind a search: someone browsing
    /// the catalog has to be able to come across it.
    func testTheToolIsListedInTheCatalog() {
        self.launch()

        let tile = self.app.staticTexts[self.toolTitle]
        if tile.waitForExistence(timeout: 5) { return }
        // The grid is lazy: the Create family runs past the fold on a phone.
        self.app.swipeUp()
        XCTAssertTrue(tile.waitForExistence(timeout: 10),
                      "the tool is not in the catalog, only in search")
    }

    // MARK: - Running it

    /// Pressing it asks for a file. What the picker then hands over is the
    /// parser's business; that it opens at all is this tool's.
    func testRunningTheToolAsksForAFile() {
        self.launch()
        self.search("p7m")
        self.tap(self.app.staticTexts[self.toolTitle])

        // The document picker is a system sheet in its own window, so it is
        // recognised by its own furniture rather than by anything of ours.
        let picker = self.app.navigationBars.buttons["Cancel"]
        XCTAssertTrue(picker.waitForExistence(timeout: 20),
                      "the tool did not open a file picker")
    }

    // MARK: - Helpers

    private func showTools() {
        let name = "Tools"
        let inBar = self.app.tabBars.firstMatch.buttons[name]
        if inBar.waitForExistence(timeout: 20) { return self.tap(inBar) }

        let asButton = self.app.buttons[name].firstMatch
        if asButton.exists { return self.tap(asButton) }

        // iPad and the Mac: the same sections are sidebar rows, which reach the
        // tree as static text.
        let asRow = self.app.staticTexts[name].firstMatch
        XCTAssertTrue(asRow.waitForExistence(timeout: 10),
                      "Tools is neither a tab, a button nor a sidebar row")
        self.tap(asRow)
    }

    private func search(_ query: String) {
        let field = self.app.searchFields["Search tools"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "the tool search is missing")
        self.tap(field)
        field.typeText(query)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) never appeared", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
