//
//  ArchiveFilingUITests.swift
//  PdfExpertUITests
//
//  Section 3 of the device round, done on a simulator.
//
//  Filing and search are the part of the archive that can be exercised without
//  a second device: making a folder, making a tag, deleting a folder and — the
//  promise the sheet prints under the list — keeping its documents, and finding
//  a document by its name and by words that only exist inside the page.
//
//  What is deliberately NOT here: iCloud sync and the two-device folder merge.
//  Those need a signed-in iCloud account, which is a credential, and the merge
//  only happens when two devices write the same name. They stay on the manual
//  list.
//
//  Same tapping rule as EditorNavigationUITests: `XCUIElement.tap()` never fires
//  in this app — the SwiftUI buttons report `isHittable = false` — so every
//  touch goes through `tap(_:)`, which synthesises one at the element's centre.
//

import XCTest

final class ArchiveFilingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    override func tearDown() {
        self.app = nil
        super.tearDown()
    }

    /// The seed puts five documents, two folders ("Work", "Home") and two tags
    /// ("Urgent", "2026") into an empty archive. Pinned to English because the
    /// screens are recognised by their titles.
    private func launch(showingOrganizer: Bool = false) {
        self.app.launchArguments = ["-AppleLanguages", "(en)",
                                    "-onboardingShown", "YES",
                                    "-debugPremium", "YES",
                                    "-debugSeedArchive", "YES"]
        if showingOrganizer {
            self.app.launchArguments += ["-debugShowOrganizer", "YES"]
        }
        self.app.launch()
    }

    // MARK: - Folders and tags

    func testANewFolderIsCreatedAndListed() {
        self.launch(showingOrganizer: true)
        self.waitForOrganizer()

        self.tap(self.app.buttons["New folder"])

        let field = self.app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the folder sheet has no name field")
        self.tap(field)
        field.typeText("Contracts")
        self.tap(self.app.buttons["Save"])

        XCTAssertTrue(self.app.staticTexts["Contracts"].waitForExistence(timeout: 10),
                      "the new folder is not in the list")
        // The ones the seed made are still there: creating is not replacing.
        XCTAssertTrue(self.app.staticTexts["Work"].exists)
        XCTAssertTrue(self.app.staticTexts["Home"].exists)
    }

    func testANewTagIsCreatedAndListed() {
        self.launch(showingOrganizer: true)
        self.waitForOrganizer()

        self.tap(self.app.buttons["New tag"])

        let field = self.app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the tag sheet has no name field")
        self.tap(field)
        field.typeText("Receipts")
        self.tap(self.app.buttons["Save"])

        XCTAssertTrue(self.app.staticTexts["Receipts"].waitForExistence(timeout: 10),
                      "the new tag is not in the list")
        XCTAssertTrue(self.app.staticTexts["Urgent"].exists)
    }

    /// The sheet promises "Deleting a folder keeps its documents — they go back
    /// to Unfiled." This is that sentence, checked: the seed files four of its
    /// five documents into Work and Home, and all five have to survive the
    /// folder that held them.
    func testDeletingAFolderKeepsItsDocuments() {
        self.launch(showingOrganizer: true)
        self.waitForOrganizer()

        // The label, not the row: "Work" also names a filter chip on the screen
        // underneath, so an unqualified query matches two elements and the swipe
        // refuses to choose. The cell containing it is unambiguous.
        let row = self.app.cells.containing(.staticText, identifier: "Work").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the seeded folders never appeared")
        row.swipeLeft()
        self.tap(self.app.buttons["Delete"].firstMatch)

        // Deleting asks first. The dialog is what carries the promise being
        // tested here — "The documents inside will be kept." — so it is worth
        // failing loudly if it ever stops appearing.
        let confirmation = self.app.sheets.buttons["Delete"].firstMatch
        let alternative = self.app.alerts.buttons["Delete"].firstMatch
        if confirmation.waitForExistence(timeout: 10) {
            self.tap(confirmation)
        } else if alternative.exists {
            self.tap(alternative)
        } else {
            return XCTFail("deleting a folder asked for no confirmation")
        }

        XCTAssertTrue(self.waitForDisappearance(of: row), "the folder was not deleted")

        self.dismissOrganizer()

        for name in ["Rental agreement.pdf", "Invoice 2026-07.pdf", "Scanned receipt.pdf",
                     "Passport scan.pdf", "Meeting notes.pdf"] {
            XCTAssertTrue(self.app.buttons[name].firstMatch.waitForExistence(timeout: 15),
                          "\(name) disappeared with its folder")
        }
    }

    // MARK: - Search

    func testSearchFindsADocumentByItsFilename() {
        self.launch()
        self.search(for: "Invoice")

        XCTAssertTrue(self.app.buttons["Invoice 2026-07.pdf"].firstMatch.waitForExistence(timeout: 15),
                      "searching for a filename found nothing")
    }

    /// The one that proves the index is doing something a filename cannot: the
    /// seeded document's pages read "Lorem ipsum", which appears in no file name
    /// at all. It is written into `searchableText` when the document is saved —
    /// which is also why a PDF added before that existed only matches by name.
    func testSearchFindsWordsThatOnlyExistInsideThePage() {
        self.launch()
        self.search(for: "Lorem")

        XCTAssertTrue(self.app.buttons["Meeting notes.pdf"].firstMatch.waitForExistence(timeout: 15),
                      "searching the text inside the documents found nothing")
    }

    func testSearchingForSomethingAbsentFindsNoDocument() {
        self.launch()
        self.search(for: "Zzyzx")

        XCTAssertFalse(self.app.buttons["Meeting notes.pdf"].firstMatch.waitForExistence(timeout: 5),
                       "a query matching nothing still listed a document")
    }

    // MARK: - Helpers

    private func waitForOrganizer() {
        XCTAssertTrue(self.app.navigationBars["Folders & Tags"].waitForExistence(timeout: 30),
                      "the organizer sheet did not open")
    }

    private func dismissOrganizer() {
        let bar = self.app.navigationBars["Folders & Tags"]
        if bar.exists {
            let done = bar.buttons.element(boundBy: bar.buttons.count - 1)
            self.tap(done)
        }
    }

    /// Search lives in its own tab. `debugInitialTab` is read at launch, but the
    /// archive has to be seeded first, so the tab is switched here instead.
    private func search(for query: String) {
        let tab = self.app.tabBars.buttons["Search"]
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "the tab bar never appeared")
        self.tap(tab)

        let field = self.app.searchFields["Search documents and tools"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the search field is missing")
        self.tap(field)
        field.typeText(query)
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                             object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
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
