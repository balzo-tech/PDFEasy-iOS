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
//  The screen they check is the third one: a canvas, a text field, and three
//  doors — Picture, Text, Style — with the two ways out in the navigation bar.
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

    // MARK: - Getting it out

    /// Two ways out and no third, both behind the one button in the bar. "To
    /// PDF" used to be here and was the only door that skipped the paywall.
    func testTheExportMenuOffersSharingAndSavingAndNothingElse() {
        self.launch()
        let field = self.app.textFields["memeCaptionField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        self.tap(field)
        field.typeText("READY")
        // Dismiss the keyboard, or it sits over the bar the menu is in. The
        // only "Done" on screen is the one above it: the field's own return key
        // says "return", because that is what it writes.
        self.tap(self.app.buttons["Done"].firstMatch)

        self.tap(self.app.buttons["Export"].firstMatch)

        for way in ["Share", "Save to Photos"] {
            XCTAssertTrue(self.app.buttons[way].waitForExistence(timeout: 10),
                          "the export menu is missing \(way)")
        }
        XCTAssertFalse(self.app.buttons["To PDF"].exists,
                       "the meme maker still offers a PDF")
    }

    // MARK: - Style

    /// Face, size, alignment and colour left the canvas for a panel; what
    /// matters is that they are still all reachable, in one place, in one tap.
    func testTheStylePanelHoldsTheFacesTheSizeAndTheAlignment() {
        self.launch()
        XCTAssertTrue(self.app.textFields["memeCaptionField"].waitForExistence(timeout: 15))

        self.tap(self.app.buttons["Style"].firstMatch)

        for face in ["Impact", "Sans", "Rounded", "Marker"] {
            XCTAssertTrue(self.app.buttons[face].waitForExistence(timeout: 10),
                          "the \(face) face is not offered")
        }
        XCTAssertTrue(self.app.sliders["Size"].waitForExistence(timeout: 5),
                      "there is no way to set the size")
        XCTAssertTrue(self.app.buttons["Align left"].waitForExistence(timeout: 5),
                      "there is no way to align the words")

        // Picking one must not throw the user out of the panel.
        self.tap(self.app.buttons["Marker"])
        XCTAssertTrue(self.app.buttons["Impact"].exists, "changing the face closed the panel")

        self.tap(self.app.buttons["Done"].firstMatch)
        XCTAssertTrue(self.app.textFields["memeCaptionField"].waitForExistence(timeout: 5),
                      "closing the style panel did not bring the editor back")
    }

    /// The canvas is the point of the screen: the controls under it are a field
    /// and three doors, and the gallery is not one of the things permanently
    /// taking its room.
    func testTheEditorShowsOnlyTheFieldAndTheThreeDoors() {
        self.launch()
        XCTAssertTrue(self.app.textFields["memeCaptionField"].waitForExistence(timeout: 15))

        for door in ["Choose a picture", "Add text", "Style"] {
            XCTAssertTrue(self.app.buttons[door].waitForExistence(timeout: 10),
                          "the \(door) door is missing")
        }
        XCTAssertFalse(self.app.staticTexts["Template"].exists,
                       "the template strip is still under the canvas")
        XCTAssertFalse(self.app.buttons["Make"].exists,
                       "the Make/Share picker is still there")
    }

    /// Alignment is the one control that has to travel the whole way: panel to
    /// model to canvas to file. This checks the visible half of it — the words
    /// really move on the picture — because a segmented control that changes
    /// nothing looks exactly like one that works.
    func testAligningLeftMovesTheWordsOnThePicture() {
        self.launch()
        let field = self.app.textFields["memeCaptionField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        self.tap(field)
        field.typeText("HI")
        self.tap(self.app.buttons["Done"].firstMatch)

        let words = self.blockOnThePicture
        XCTAssertTrue(words.waitForExistence(timeout: 10), "the words never reached the picture")
        let centred = words.frame.minX

        self.tap(self.app.buttons["Style"].firstMatch)
        self.tap(self.app.buttons["Align left"])
        self.tap(self.app.buttons["Done"].firstMatch)

        let aligned = self.blockOnThePicture
        XCTAssertTrue(aligned.waitForExistence(timeout: 10))
        XCTAssertLessThan(aligned.frame.minX, centred - 20,
                          "aligning left left the words where they were")
    }

    // MARK: - Helpers

    /// The block the user has been writing in, as the canvas draws it. The
    /// second block on the picture is still blank and carries the placeholder,
    /// so the one wanted here is the one whose label is the typed words.
    private var blockOnThePicture: XCUIElement {
        self.app.descendants(matching: .any)
            .matching(identifier: "memeCaptionBlock")
            // Begins with, not equals: the field is multi-line, so what comes
            // back carries whatever the keyboard's return key left behind.
            .matching(NSPredicate(format: "label BEGINSWITH %@", "HI"))
            .firstMatch
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) never appeared", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
