//
//  MemeMakerUITests.swift
//  PdfExpertUITests
//
//  The meme maker's one job, checked from the outside: can a person write on the
//  picture.
//
//  These exist because the answer was no, and nothing caught it. The editor had
//  a `TextField` over each block of words and bound the focus with `.focused` on
//  the block's *container*, which is not a focusable view — so the keyboard never
//  came up, the tool shipped, and it took a person opening it to notice. A test
//  that asks for the keyboard would have failed on the first run.
//
//  Same tapping rule as the other UI tests here: `XCUIElement.tap()` never fires
//  in this app — the SwiftUI buttons report `isHittable = false` — so every touch
//  goes through `tap(_:)`, which synthesises one at the element's centre.
//
//  `debugRunTool meme-photo` opens the editor on a drawn photograph rather than
//  on a downloaded template: the catalogue comes off the network, and a test that
//  waits for it is a test that fails on a bad morning.
//

import XCTest

final class MemeMakerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    private func launch() {
        self.app.launchArguments = ["-AppleLanguages", "(en)",
                                    "-onboardingShown", "YES",
                                    "-debugPremium", "YES",
                                    // The tool runs from the Tools tab's onAppear,
                                    // so that tab has to be the one on screen.
                                    "-debugInitialTab", "1",
                                    "-debugRunTool", "meme-photo"]
        self.app.launch()
        XCTAssertTrue(self.app.staticTexts["Meme maker"].waitForExistence(timeout: 30),
                      "the meme editor never opened")
    }

    // MARK: - Writing

    /// The regression this file was written for.
    func testTappingTheCaptionFieldRaisesTheKeyboard() {
        self.launch()

        // The first picture brings two blocks and selects one, so the field is
        // already pointed at something and says so.
        let field = self.app.textFields["memeCaptionField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "there is nowhere to type the caption")

        self.tap(field)
        XCTAssertTrue(self.app.keyboards.element.waitForExistence(timeout: 10),
                      "tapping the caption field brought no keyboard")

        field.typeText("HELLO")
        XCTAssertEqual(field.value as? String, "HELLO", "what was typed did not reach the caption")
    }

    /// Adding a block should land the user in it, not leave them hunting for it.
    func testAddingABlockOpensTheKeyboardOnIt() {
        self.launch()
        XCTAssertTrue(self.app.textFields["memeCaptionField"].waitForExistence(timeout: 15))

        self.tap(self.app.buttons["Add text"])

        XCTAssertTrue(self.app.keyboards.element.waitForExistence(timeout: 10),
                      "adding a block did not open the keyboard on it")
        let field = self.app.textFields["memeCaptionField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // An empty field reports its placeholder as its value, so this is also
        // the check that a brand new block starts blank.
        XCTAssertEqual(field.value as? String, "Type the caption",
                       "the new block did not start empty")
    }

    // MARK: - The two panels

    func testTheShareSectionHoldsTheThreeWaysOutAndNoEditingControls() {
        self.launch()
        let field = self.app.textFields["memeCaptionField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        self.tap(field)
        field.typeText("READY")

        self.tap(self.app.buttons["Share"].firstMatch)

        for way in ["Share", "Save to Photos", "To PDF"] {
            XCTAssertTrue(self.app.buttons[way].waitForExistence(timeout: 10),
                          "the Share section is missing \(way)")
        }
        // The point of the split: the styling and the gallery are not here, and
        // neither is the keyboard.
        XCTAssertFalse(self.app.textFields["memeCaptionField"].exists,
                       "the caption field followed the user into Share")
        XCTAssertFalse(self.app.staticTexts["Template"].exists,
                       "the template strip followed the user into Share")
    }

    func testTheFaceChipsAreOfferedAndCanBeChanged() {
        self.launch()
        XCTAssertTrue(self.app.textFields["memeCaptionField"].waitForExistence(timeout: 15))

        for face in ["Impact", "Sans", "Rounded", "Marker"] {
            XCTAssertTrue(self.app.buttons[face].waitForExistence(timeout: 10),
                          "the \(face) face is not offered")
        }
        // Picking one must not throw the user out of the editor or lose the panel.
        self.tap(self.app.buttons["Marker"])
        XCTAssertTrue(self.app.textFields["memeCaptionField"].waitForExistence(timeout: 5),
                      "changing the face closed the edit panel")
    }

    // MARK: - Helpers

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) never appeared", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
