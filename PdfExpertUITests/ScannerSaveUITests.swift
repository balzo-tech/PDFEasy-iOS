//
//  ScannerSaveUITests.swift
//  PdfExpertUITests
//
//  Reported from the device: a scan saved as a PDF does not appear in the
//  Scanner tab.
//
//  A simulator has no camera, but it does not need one to reach the end of the
//  flow: `debugScanPages` seeds two drawn captures and `debugScanSave` opens the
//  save sheet over them, which is the same sheet a real scan arrives at. What
//  happens after "Save as PDF" — the write, the archive refresh, the filter the
//  tab applies — is ordinary code, and that is the part being reported.
//

import XCTest

final class ScannerSaveUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
        self.app.launchArguments = ["-AppleLanguages", "(en)",
                                    "-onboardingShown", "YES",
                                    "-debugPremium", "YES",
                                    "-debugStartScan", "YES",
                                    "-debugScanPages", "YES",
                                    "-debugScanSave", "YES"]
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    /// Save, then look for the document where the user looks for it.
    func testAScanSavedAsPdfAppearsInTheScannerTab() {
        self.app.launch()

        let sheet = self.app.staticTexts["Scan complete"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 30), "the save sheet never opened")

        // The name it offers is dated and timed; the archive is searched by it
        // afterwards, so it has to be read before saving rather than guessed.
        let field = self.app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the save sheet has no name field")
        let proposedName = (field.value as? String) ?? ""
        XCTAssertFalse(proposedName.isEmpty, "the save sheet proposed no file name")

        self.tap(self.app.buttons["Save as PDF"])

        // The flow closes itself on success and leaves the Scanner tab behind it.
        XCTAssertTrue(self.waitForDisappearance(of: sheet, timeout: 30),
                      "the save sheet stayed up, so saving never finished")

        // The card is labelled with the name the user typed, without the
        // extension — the archive adds `.pdf` on the way to disk.
        let card = self.app.buttons[proposedName].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20),
                      "the saved scan is not in the Scanner tab")

        // The card carries a thumbnail of the first page. Nothing in the
        // accessibility tree can tell whether it drew, so the screenshot goes
        // into the result bundle for a person to look at.
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "scanner-tab-after-saving"
        shot.lifetime = .keepAlways
        self.add(shot)
    }

    // MARK: - Helpers

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                             object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    /// `tap()` never fires in this app — see EditorNavigationUITests.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) never appeared", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
