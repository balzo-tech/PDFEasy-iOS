//
//  PersistenceDeduplicationTests.swift
//  PdfExpertTests
//
//  Two devices that each create the folder "Work" while offline produce two
//  records. These cover the merge that puts them back together, and — just as
//  importantly — the cases it must leave alone.
//

import XCTest
import CoreData
@testable import PdfExpert

final class PersistenceDeduplicationTests: XCTestCase {

    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        self.persistence = PersistenceController(inMemory: true)
        self.context = self.persistence.container.viewContext
    }

    override func tearDown() {
        self.context = nil
        self.persistence = nil
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func makeFolder(name: String?, daysAgo: Double, color: Int32 = 0) -> CDFolder {
        let folder = CDFolder(context: self.context)
        folder.name = name
        folder.colorIndex = color
        folder.creationDate = Date(timeIntervalSince1970: 1_000_000 - daysAgo * 86_400)
        return folder
    }

    @discardableResult
    private func makeTag(name: String, daysAgo: Double, color: Int32 = 0) -> CDTag {
        let tag = CDTag(context: self.context)
        tag.name = name
        tag.colorIndex = color
        tag.creationDate = Date(timeIntervalSince1970: 1_000_000 - daysAgo * 86_400)
        return tag
    }

    private func makePdf(filename: String) -> CDPdf {
        let pdf = CDPdf(context: self.context)
        pdf.filename = filename
        pdf.creationDate = Date(timeIntervalSince1970: 1_000_000)
        return pdf
    }

    private func fetchAll(_ entityName: String) -> [NSManagedObject] {
        (try? self.context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName))) ?? []
    }

    // MARK: - Folders

    /// The duplicate goes, the survivor is the older record, and the documents of
    /// both end up filed under it.
    func testMergesFoldersWithTheSameName() {
        let older = self.makeFolder(name: "Work", daysAgo: 10)
        let newer = self.makeFolder(name: "Work", daysAgo: 1)
        self.makePdf(filename: "a.pdf").folder = older
        self.makePdf(filename: "b.pdf").folder = newer

        self.persistence.deduplicateNamedEntities(in: self.context)

        let folders = self.fetchAll("Folder")
        XCTAssertEqual(folders.count, 1, "the duplicate folder must be merged away")
        XCTAssertEqual((folders.first as? CDFolder)?.creationDate, older.creationDate,
                       "the older record must be the one kept")
        XCTAssertEqual((folders.first as? CDFolder)?.pdfs?.count, 2,
                       "both documents must survive the merge, re-filed onto the survivor")
    }

    /// A duplicate is what a person would call one: case and stray spaces do not
    /// make a second folder.
    func testMergesFoldersDifferingOnlyByCaseOrSpacing() {
        self.makeFolder(name: "Work", daysAgo: 10)
        self.makeFolder(name: "  work ", daysAgo: 1)

        self.persistence.deduplicateNamedEntities(in: self.context)

        XCTAssertEqual(self.fetchAll("Folder").count, 1)
    }

    /// Folders that are genuinely different must all still be there afterwards.
    func testKeepsFoldersWithDifferentNames() {
        self.makeFolder(name: "Work", daysAgo: 10)
        self.makeFolder(name: "Home", daysAgo: 5)
        self.makeFolder(name: "Taxes", daysAgo: 1)

        self.persistence.deduplicateNamedEntities(in: self.context)

        XCTAssertEqual(self.fetchAll("Folder").count, 3)
    }

    /// Nameless records are already treated as corrupt elsewhere; the merge must
    /// not quietly collapse them all into one.
    func testLeavesNamelessFoldersAlone() {
        self.makeFolder(name: nil, daysAgo: 10)
        self.makeFolder(name: "", daysAgo: 5)
        self.makeFolder(name: "   ", daysAgo: 1)

        self.persistence.deduplicateNamedEntities(in: self.context)

        XCTAssertEqual(self.fetchAll("Folder").count, 3)
    }

    /// Three copies of the same folder collapse to one, not to two.
    func testMergesMoreThanTwoDuplicates() {
        let oldest = self.makeFolder(name: "Work", daysAgo: 30)
        self.makeFolder(name: "Work", daysAgo: 20)
        self.makeFolder(name: "Work", daysAgo: 10)
        self.makePdf(filename: "a.pdf").folder = oldest

        self.persistence.deduplicateNamedEntities(in: self.context)

        let folders = self.fetchAll("Folder")
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual((folders.first as? CDFolder)?.pdfs?.count, 1)
    }

    // MARK: - Tags

    /// Tags are many-to-many: a document tagged with both copies must come out
    /// tagged once, with the surviving tag.
    func testMergesTagsWithTheSameName() {
        let older = self.makeTag(name: "Invoice", daysAgo: 10)
        let newer = self.makeTag(name: "Invoice", daysAgo: 1)
        let pdf = self.makePdf(filename: "a.pdf")
        pdf.mutableSetValue(forKey: "tags").add(older)
        let otherPdf = self.makePdf(filename: "b.pdf")
        otherPdf.mutableSetValue(forKey: "tags").add(newer)

        self.persistence.deduplicateNamedEntities(in: self.context)

        let tags = self.fetchAll("Tag")
        XCTAssertEqual(tags.count, 1, "the duplicate tag must be merged away")
        XCTAssertEqual((tags.first as? CDTag)?.creationDate, older.creationDate)
        XCTAssertEqual((tags.first as? CDTag)?.pdfs?.count, 2,
                       "both documents must keep the tag")
        XCTAssertEqual(pdf.tagList.count, 1)
        XCTAssertEqual(otherPdf.tagList.first?.name, "Invoice")
    }

    // MARK: - Agreement between devices

    /// The whole scheme rests on this: two devices holding the same records must
    /// keep the same one, whatever order they happen to have stored them in. If
    /// they disagreed, each would delete what the other kept.
    func testSurvivorDoesNotDependOnInsertionOrder() {
        self.makeFolder(name: "Work", daysAgo: 1, color: 3)
        self.makeFolder(name: "Work", daysAgo: 10, color: 5)
        self.persistence.deduplicateNamedEntities(in: self.context)

        // A second device, same two folders, stored the other way round.
        let otherPersistence = PersistenceController(inMemory: true)
        let otherContext = otherPersistence.container.viewContext
        for (daysAgo, color) in [(10.0, Int32(5)), (1.0, Int32(3))] {
            let folder = CDFolder(context: otherContext)
            folder.name = "Work"
            folder.colorIndex = color
            folder.creationDate = Date(timeIntervalSince1970: 1_000_000 - daysAgo * 86_400)
        }
        otherPersistence.deduplicateNamedEntities(in: otherContext)

        let survivor = self.fetchAll("Folder").first as? CDFolder
        let otherSurvivor = (try? otherContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "Folder")))?
            .first as? CDFolder
        XCTAssertEqual(survivor?.creationDate, otherSurvivor?.creationDate,
                       "both devices must keep the same record")
        XCTAssertEqual(survivor?.colorIndex, otherSurvivor?.colorIndex)
    }

    /// Same name and same date: the tie still has to break the same way on both
    /// devices, and the surviving color says which one it picked.
    func testSurvivorIsDecidedByColorWhenDatesMatch() {
        self.makeFolder(name: "Work", daysAgo: 5, color: 7)
        self.makeFolder(name: "Work", daysAgo: 5, color: 2)

        self.persistence.deduplicateNamedEntities(in: self.context)

        let folders = self.fetchAll("Folder")
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual((folders.first as? CDFolder)?.colorIndex, 2,
                       "with equal dates the lower color index wins, on every device")
    }

    /// A pass over an archive with nothing to merge must change nothing.
    func testNothingToMergeIsANoOp() {
        self.makeFolder(name: "Work", daysAgo: 10)
        self.makeTag(name: "Invoice", daysAgo: 10)

        self.persistence.deduplicateNamedEntities(in: self.context)

        XCTAssertEqual(self.fetchAll("Folder").count, 1)
        XCTAssertEqual(self.fetchAll("Tag").count, 1)
    }
}
