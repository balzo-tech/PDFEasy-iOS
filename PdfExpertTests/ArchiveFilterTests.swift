//
//  ArchiveFilterTests.swift
//  PdfExpertTests
//
//  The rules behind the Files tab's filter bar: one folder at a time, tags that
//  narrow further, and a search that also looks at what a document is filed
//  under. Exercised over a stand-in document so no Core Data stack is needed.
//

import XCTest
@testable import PdfExpert

final class ArchiveFilterTests: XCTestCase {

    private struct Document: ArchiveFilterable {
        var filename: String
        var searchableText: String? = nil
        var folderId: String? = nil
        var folderName: String? = nil
        var tagIds: [String] = []
        var tagNames: [String] = []
    }

    private let invoice = Document(filename: "Invoice 2026-07.pdf",
                                   searchableText: "Total due 240 EUR",
                                   folderId: "folder-work",
                                   folderName: "Work",
                                   tagIds: ["tag-urgent", "tag-2026"],
                                   tagNames: ["Urgent", "2026"])
    private let contract = Document(filename: "Rental agreement.pdf",
                                    searchableText: "The tenant agrees",
                                    folderId: "folder-work",
                                    folderName: "Work",
                                    tagIds: ["tag-2026"],
                                    tagNames: ["2026"])
    private let receipt = Document(filename: "Scanned receipt.pdf",
                                   tagIds: ["tag-urgent"],
                                   tagNames: ["Urgent"])

    private var all: [Document] { [self.invoice, self.contract, self.receipt] }

    // MARK: - Folder

    func testNoFilterReturnsEverything() {
        let filter = ArchiveFilter()
        XCTAssertEqual(filter.apply(to: self.all).count, 3)
        XCTAssertFalse(filter.isFiltering)
    }

    func testFolderFilterKeepsOnlyThatFolder() {
        var filter = ArchiveFilter()
        filter.folder = .folder(id: "folder-work")
        let result = filter.apply(to: self.all)
        XCTAssertEqual(result.map(\.filename), [self.invoice.filename, self.contract.filename])
        XCTAssertTrue(filter.isFiltering)
    }

    func testUnfiledFilterKeepsDocumentsWithNoFolder() {
        var filter = ArchiveFilter()
        filter.folder = .unfiled
        XCTAssertEqual(filter.apply(to: self.all).map(\.filename), [self.receipt.filename])
    }

    // MARK: - Tags

    func testTagFilterKeepsTaggedDocuments() {
        var filter = ArchiveFilter()
        filter.tagIds = ["tag-urgent"]
        XCTAssertEqual(filter.apply(to: self.all).map(\.filename),
                       [self.invoice.filename, self.receipt.filename])
    }

    /// Two tags narrow down, they don't widen: only documents carrying both stay.
    func testMultipleTagsRequireAllOfThem() {
        var filter = ArchiveFilter()
        filter.tagIds = ["tag-urgent", "tag-2026"]
        XCTAssertEqual(filter.apply(to: self.all).map(\.filename), [self.invoice.filename])
    }

    func testFolderAndTagsCombine() {
        var filter = ArchiveFilter()
        filter.folder = .folder(id: "folder-work")
        filter.tagIds = ["tag-urgent"]
        XCTAssertEqual(filter.apply(to: self.all).map(\.filename), [self.invoice.filename])
    }

    func testFilterPointingAtNothingReturnsEmpty() {
        var filter = ArchiveFilter()
        filter.folder = .folder(id: "folder-deleted")
        XCTAssertTrue(filter.apply(to: self.all).isEmpty)
    }

    // MARK: - Search

    func testSearchMatchesFilenameAndPageText() {
        var filter = ArchiveFilter()
        filter.searchText = "invoice"
        XCTAssertEqual(filter.apply(to: self.all).map(\.filename), [self.invoice.filename])

        filter.searchText = "tenant"
        XCTAssertEqual(filter.apply(to: self.all).map(\.filename), [self.contract.filename])
    }

    func testSearchMatchesFolderAndTagNames() {
        var filter = ArchiveFilter()
        filter.searchText = "work"
        XCTAssertEqual(filter.apply(to: self.all).count, 2)

        filter.searchText = "urgent"
        XCTAssertEqual(filter.apply(to: self.all).map(\.filename),
                       [self.invoice.filename, self.receipt.filename])
    }

    func testSearchIgnoresCaseDiacriticsAndSurroundingSpace() {
        var filter = ArchiveFilter()
        filter.searchText = "  ínvoíce "
        XCTAssertEqual(filter.apply(to: self.all).map(\.filename), [self.invoice.filename])
    }

    func testSearchAppliesOnTopOfTheActiveFilters() {
        var filter = ArchiveFilter()
        filter.folder = .unfiled
        filter.searchText = "invoice"
        // The invoice matches the query but is filed under Work.
        XCTAssertTrue(filter.apply(to: self.all).isEmpty)
    }

    func testSearchOnlyIsNotConsideredFiltering() {
        var filter = ArchiveFilter()
        filter.searchText = "invoice"
        XCTAssertFalse(filter.isFiltering)
    }
}
