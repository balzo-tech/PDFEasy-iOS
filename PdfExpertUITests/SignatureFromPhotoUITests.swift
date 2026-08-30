//
//  SignatureFromPhotoUITests.swift
//  PdfExpertUITests
//
//  A signature can be drawn, chosen from the photo library or taken with the
//  camera, and the two that come from a picture are the ones nothing could check:
//  they cross the photo picker and the cropper, two presentations stacked on top of
//  a sheet that is itself on top of another. Driving the system photo picker from a
//  test is its own fight, and losing it says nothing about the app — so what is
//  checked here is everything up to the picker's door, which is where this flow has
//  actually gone wrong: the screen it opens, what that screen calls itself, and the
//  three ways in.
//
//  As everywhere in this bundle, `XCUIElement.tap()` does not fire on this app's
//  SwiftUI buttons — see the note at the top of `EditorNavigationUITests`.
//

import XCTest

final class SignatureFromPhotoUITests: XCTestCase {

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
                                    "-debugSeedArchive", "YES",
                                    "-debugPremium", "YES"]
        self.app.launch()
    }

    /// The screen used to call itself "Tap where you wish to add text": it sets a
    /// navigation title twice, and the inner one — copied from the text tool — is
    /// the one that reaches the bar.
    func testTheSignatureScreenAsksWhereToSignAndNotWhereToAddText() {
        self.launch()
        self.openTheFirstDocument()
        self.tap(self.app.buttons["Sign PDF"].firstMatch)

        guard self.app.buttons["Finish"].firstMatch.waitForExistence(timeout: 15) else {
            print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            return XCTFail("the signature screen did not open")
        }
        XCTAssertTrue(self.app.navigationBars["Tap where you wish to sign"].exists,
                      "the signature screen is not asking where to sign")
        XCTAssertFalse(self.app.navigationBars["Tap where you wish to add text"].exists,
                       "the signature screen is asking where to add text")
    }

    /// The sheet a tap on the page opens, with its three ways to make a signature.
    /// Choosing a picture leads out to the photo picker and the cropper, which this
    /// cannot follow — but the sheet has to be there and offer all three.
    func testTappingThePageOffersDrawingAPictureAndTheCamera() {
        self.launch()
        self.openTheFirstDocument()
        self.tap(self.app.buttons["Sign PDF"].firstMatch)
        XCTAssertTrue(self.app.buttons["Finish"].firstMatch.waitForExistence(timeout: 15),
                      "the signature screen did not open")

        self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        self.openSignatureCreation()
        for source in ["Drawing", "From Image", "From Camera"] {
            XCTAssertTrue(self.app.buttons[source].firstMatch.exists, "\(source) is not offered")
        }
        // Nothing has been signed yet, so there is nothing to confirm.
        XCTAssertFalse(self.app.buttons["Confirm"].firstMatch.isEnabled,
                       "Confirm is on before there is a signature")
    }

    // MARK: - Getting there

    private func openTheFirstDocument() {
        let card = self.app.buttons["Meeting notes.pdf"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the seeded archive never appeared")
        self.tap(card)
        XCTAssertTrue(self.app.navigationBars["Meeting notes.pdf"].buttons["Tools"].waitForExistence(timeout: 15),
                      "the document did not open")
    }

    /// A tap on the page opens the creation sheet only when nothing has been signed
    /// before; once a signature is saved it opens the library instead, and the way
    /// on is "Add new signature". Signatures outlive a test run — they are in the
    /// store, which the simulator keeps — so which of the two screens appears
    /// depends on what ran earlier. Both are handled rather than assuming an empty
    /// library, which is what used to make these tests fail on a second run.
    private func openSignatureCreation(file: StaticString = #filePath, line: UInt = #line) {
        let library = self.app.staticTexts["Your Signatures"].firstMatch
        if library.waitForExistence(timeout: 5) {
            self.tap(self.app.buttons["Add new signature"].firstMatch)
        }
        guard self.app.staticTexts["Add Signature"].waitForExistence(timeout: 15) else {
            print("UITREE-BEGIN\n\(self.app.debugDescription)\nUITREE-END")
            return XCTFail("tapping the page did not open the signature sheet",
                           file: file, line: line)
        }
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) never appeared", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
