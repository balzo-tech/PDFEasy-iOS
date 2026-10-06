//
//  PageCropShotsUITests.swift
//  PdfExpertUITests
//
//  Pictures of the crop tool, for looking at rather than for asserting on:
//  the bar with Crop in it, the crop screen, the cropped page, the same page
//  after a save and a relaunch, and a page turned a quarter and then cropped.
//
//  Skipped unless asked for, since it is slow and its output is screenshots:
//    TEST_RUNNER_CROP_SHOTS=it xcodebuild … -only-testing:PdfExpertUITests/PageCropShotsUITests test
//  Any language shoots the bar and the crop screen; `en` also does the rest,
//  which is recognised by English labels. The pictures are attachments of the
//  result bundle (`xcrun xcresulttool export attachments`).
//
//  `tap()` does not work in this app (see `EditorNavigationUITests`): every
//  press here is a coordinate.
//

import XCTest

final class PageCropShotsUITests: XCTestCase {

    private var app: XCUIApplication!
    private var language = "en"

    override func setUpWithError() throws {
        self.continueAfterFailure = false
        self.app = XCUIApplication()
    }

    func testShootTheCropTool() throws {
        guard let language = ProcessInfo.processInfo.environment["CROP_SHOTS"], !language.isEmpty else {
            throw XCTSkip("set TEST_RUNNER_CROP_SHOTS=<language> to shoot the crop tool")
        }
        self.language = language
        self.launch(language: language, resetArchive: true)
        self.openTheFirstDocument()
        self.shoot("\(language)-1-bar")

        self.tap(self.app.buttons["editorBar.cropPage"])
        let page = self.app.images.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cropPage.page@")).firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 15), "the crop screen never drew the page")
        // The right side in to the middle, the top down a fifth.
        self.drag(in: self.drawnPageFrame(of: page), from: CGPoint(x: 1, y: 0.5), to: CGPoint(x: 0.55, y: 0.5))
        self.drag(in: self.drawnPageFrame(of: page), from: CGPoint(x: 0.27, y: 0), to: CGPoint(x: 0.27, y: 0.2))
        self.shoot("\(language)-2-crop-screen")
        guard language == "en" else { return }

        self.tap(self.app.buttons["cropPage.apply"])
        XCTAssertTrue(self.app.buttons["editorBar.cropPage"].waitForExistence(timeout: 15))
        sleep(2)
        self.shoot("en-3-cropped-page")

        // Saved, the app killed and started again, the document opened afresh.
        self.tap(self.app.buttons["Save PDF"].firstMatch)
        sleep(2)
        self.app.terminate()
        self.launch(language: language, resetArchive: false)
        self.openTheFirstDocument()
        sleep(2)
        self.shoot("en-4-reopened-after-save")

        // A page turned a quarter, then cropped to the top-left quarter of what
        // is shown: what is kept must be that corner of the turned page.
        self.tap(self.app.buttons["editorBar.rotateRight"])
        sleep(1)
        self.tap(self.app.buttons["editorBar.cropPage"])
        XCTAssertTrue(page.waitForExistence(timeout: 15))
        self.tap(self.app.buttons["cropPage.reset"])
        sleep(1)
        self.drag(in: self.drawnPageFrame(of: page), from: CGPoint(x: 1, y: 1), to: CGPoint(x: 0.5, y: 0.5))
        self.shoot("en-5-rotated-crop-screen")
        self.tap(self.app.buttons["cropPage.apply"])
        XCTAssertTrue(self.app.buttons["editorBar.cropPage"].waitForExistence(timeout: 15))
        sleep(2)
        self.shoot("en-6-rotated-cropped-page")
    }

    // MARK: - Helpers

    /// Where the crop screen draws the page. The element's frame is the whole
    /// canvas; the page's shape is in its identifier (`cropPage.page@<ratio>`),
    /// and the page is fitted into the canvas the way the screen fits it.
    private func drawnPageFrame(of element: XCUIElement) -> CGRect {
        let canvas = element.frame
        guard let ratio = Double(element.identifier.replacingOccurrences(of: "cropPage.page@", with: "")),
              ratio > 0 else { return canvas }
        let scale = min(canvas.width / ratio, canvas.height)
        let size = CGSize(width: ratio * scale, height: scale)
        return CGRect(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func launch(language: String, resetArchive: Bool) {
        self.app.launchArguments = ["-AppleLanguages", "(\(language))",
                                    "-onboardingShown", "YES",
                                    "-debugSeedArchive", "YES",
                                    "-debugPremium", "YES",
                                    "-debugResetArchive", resetArchive ? "YES" : "NO"]
        self.app.launch()
    }

    private func openTheFirstDocument() {
        // The seeded documents are named in the language of the run
        // (`K.Test.DebugSeedFilenames`); the meeting notes have three pages.
        let names = ["it": "Verbale riunione", "es": "Acta de reunión", "de": "Besprechungsnotizen",
                     "fr": "Notes de réunion", "nl": "Vergadernotities", "pt-BR": "Ata de reunião"]
        let card = self.app.buttons["\(names[self.language] ?? "Meeting notes").pdf"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the seeded archive never appeared")
        self.tap(card)
        XCTAssertTrue(self.app.buttons["editorBar.cropPage"].waitForExistence(timeout: 20),
                      "the editor did not open")
    }

    /// A drag between two points given as fractions of `frame`.
    private func drag(in frame: CGRect, from: CGPoint, to: CGPoint) {
        let origin = self.app.coordinate(withNormalizedOffset: .zero)
        // Kept a few points inside, so a point on the page's edge lands on the
        // handle and not past it.
        func point(_ p: CGPoint) -> XCUICoordinate {
            origin.withOffset(CGVector(dx: frame.minX + 4 + (frame.width - 8) * p.x,
                                       dy: frame.minY + 4 + (frame.height - 8) * p.y))
        }
        point(from).press(forDuration: 0.2, thenDragTo: point(to))
    }

    private func shoot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 15) else {
            XCTFail("\(element) never appeared", file: file, line: line)
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
