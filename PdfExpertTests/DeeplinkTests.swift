//
//  DeeplinkTests.swift
//  PdfExpertTests
//
//  The widget and the App Intents reach the app through these URLs, and a typo
//  there fails silently at runtime — so the parsing is covered here.
//

import XCTest
@testable import PdfExpert

final class DeeplinkTests: XCTestCase {

    private func url(_ path: String) -> URL {
        URL(string: "\(SharedStorage.schema)\(path)")!
    }

    // MARK: - Tabs

    func testTabDeeplinks() {
        let cases: [(String, MainTab)] = [
            ("files", .files),
            ("tools", .tools),
            ("search", .search)
        ]
        for (path, expected) in cases {
            guard case .tab(let tab)? = Deeplink(fromCustomUrl: self.url(path)) else {
                return XCTFail("\(path) did not parse as a tab deeplink")
            }
            XCTAssertEqual(tab, expected)
        }
    }

    func testChatDeeplink() {
        guard case .chatPdf? = Deeplink(fromCustomUrl: self.url("chatpdf")) else {
            return XCTFail("chatpdf did not parse")
        }
    }

    func testParsingIsCaseInsensitive() {
        guard case .tab(let tab)? = Deeplink(fromCustomUrl: self.url("TOOLS")) else {
            return XCTFail("uppercase host did not parse")
        }
        XCTAssertEqual(tab, .tools)
    }

    // MARK: - Documents

    func testDocumentUrlRoundTrip() {
        // Core Data object URIs contain characters that must survive encoding.
        let identifier = "x-coredata://E8DABA5A-B67B-46FA/CDPdf/p12"
        guard let url = Deeplink.documentUrl(forId: identifier) else {
            return XCTFail("could not build the document url")
        }
        guard case .document(let parsed)? = Deeplink(fromCustomUrl: url) else {
            return XCTFail("document url did not parse")
        }
        XCTAssertEqual(parsed, identifier)
    }

    func testEmptyDocumentIdIsRejected() {
        XCTAssertNil(Deeplink(fromCustomUrl: self.url("document/")))
    }

    // MARK: - Tools

    func testToolUrlRoundTrip() {
        guard let url = Deeplink.toolUrl(forIdentifier: HomeAction.scan.identifier) else {
            return XCTFail("could not build the tool url")
        }
        guard case .tool(let identifier)? = Deeplink(fromCustomUrl: url) else {
            return XCTFail("tool url did not parse")
        }
        XCTAssertEqual(identifier, "scan")
        XCTAssertEqual(HomeAction(identifier: identifier), .scan)
    }

    func testUnknownToolIdentifierResolvesToNil() {
        XCTAssertNil(HomeAction(identifier: "notATool"))
    }

    // MARK: - Rejections

    func testForeignSchemeIsRejected() {
        XCTAssertNil(Deeplink(fromCustomUrl: URL(string: "https://balzo.eu/files")!))
    }

    func testUnknownHostIsRejected() {
        XCTAssertNil(Deeplink(fromCustomUrl: self.url("somethingElse")))
    }
}

final class SharedDocumentTests: XCTestCase {

    private func makeDocument(filename: String) -> SharedDocument {
        SharedDocument(id: "1",
                       filename: filename,
                       pageCount: 3,
                       creationDate: Date(timeIntervalSince1970: 0),
                       thumbnailName: nil)
    }

    func testDisplayNameDropsThePdfExtension() {
        XCTAssertEqual(self.makeDocument(filename: "Rental agreement.pdf").displayName, "Rental agreement")
        XCTAssertEqual(self.makeDocument(filename: "Report.PDF").displayName, "Report")
    }

    func testDisplayNameKeepsOtherNamesIntact() {
        XCTAssertEqual(self.makeDocument(filename: "Notes").displayName, "Notes")
        XCTAssertEqual(self.makeDocument(filename: "v1.2 summary").displayName, "v1.2 summary")
    }

    func testSnapshotSurvivesEncoding() throws {
        let documents = [self.makeDocument(filename: "A.pdf"), self.makeDocument(filename: "B.pdf")]
        let data = try JSONEncoder().encode(documents)
        let decoded = try JSONDecoder().decode([SharedDocument].self, from: data)
        XCTAssertEqual(decoded, documents)
    }
}
