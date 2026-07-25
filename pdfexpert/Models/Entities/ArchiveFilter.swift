//
//  ArchiveFilter.swift
//  PdfExpert
//
//  What the Files tab is currently showing: a folder, any number of tags, and
//  the search query. Kept as a value type over a narrow protocol so the rules
//  can be unit-tested without a Core Data stack behind them.
//

import Foundation

/// The bits of a document the archive filters on.
protocol ArchiveFilterable {
    var filename: String { get }
    var searchableText: String? { get }
    var folderId: String? { get }
    var folderName: String? { get }
    var tagIds: [String] { get }
    var tagNames: [String] { get }
}

enum FolderFilter: Hashable {
    /// Every document, wherever it is filed.
    case all
    /// Only the documents that are in no folder.
    case unfiled
    case folder(id: String)
}

struct ArchiveFilter: Equatable {

    var searchText: String = ""
    var folder: FolderFilter = .all
    /// Multiple tags narrow the list down: a document has to carry all of them.
    var tagIds: Set<String> = []

    /// True when something other than the search field is narrowing the list —
    /// used to decide whether the empty state should offer to clear the filters.
    var isFiltering: Bool {
        self.folder != .all || !self.tagIds.isEmpty
    }

    func apply<T: ArchiveFilterable>(to items: [T]) -> [T] {
        items.filter { self.matchesFolder($0) && self.matchesTags($0) && self.matchesSearch($0) }
    }

    private func matchesFolder(_ item: some ArchiveFilterable) -> Bool {
        switch self.folder {
        case .all: return true
        case .unfiled: return item.folderId == nil
        case .folder(let id): return item.folderId == id
        }
    }

    private func matchesTags(_ item: some ArchiveFilterable) -> Bool {
        guard !self.tagIds.isEmpty else { return true }
        return self.tagIds.isSubset(of: Set(item.tagIds))
    }

    /// Filename, indexed page text, and the names of whatever the document is
    /// filed under: typing "invoices" finds the folder's contents too.
    private func matchesSearch(_ item: some ArchiveFilterable) -> Bool {
        let query = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if Self.matches(item.filename, query) { return true }
        if Self.matches(item.searchableText, query) { return true }
        if Self.matches(item.folderName, query) { return true }
        return item.tagNames.contains { Self.matches($0, query) }
    }

    static func matches(_ text: String?, _ query: String) -> Bool {
        guard let text else { return false }
        return text.range(of: query,
                          options: [.caseInsensitive, .diacriticInsensitive],
                          locale: .current) != nil
    }
}

extension Pdf: ArchiveFilterable {

    var folderId: String? { self.folder?.id }
    var folderName: String? { self.folder?.name }
    var tagIds: [String] { self.tags.map(\.id) }
    var tagNames: [String] { self.tags.map(\.name) }
}
