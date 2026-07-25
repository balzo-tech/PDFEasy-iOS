//
//  SharedDocumentStore.swift
//  PdfExpert / PdfProWidget
//
//  A small snapshot of the archive, written by the app into the shared app
//  group so the widget can render recent documents.
//
//  The widget deliberately does not open the Core Data store: that store is
//  backed by CloudKit and lives in the app's own container, and loading it from
//  an extension would mean both a schema-visible change and a much heavier
//  timeline refresh. A JSON file plus a few small PNGs is enough for what a
//  widget shows.
//

import Foundation
import UIKit

struct SharedDocument: Codable, Identifiable, Hashable {

    /// Core Data object-id URI when available, so the app can reopen exactly
    /// this document; falls back to the filename.
    let id: String
    let filename: String
    let pageCount: Int
    let creationDate: Date
    /// File name of the thumbnail inside the shared thumbnails folder.
    let thumbnailName: String?

    /// Filename without the extension — every document here is a PDF.
    var displayName: String {
        self.filename.lowercased().hasSuffix(".pdf") ? String(self.filename.dropLast(4)) : self.filename
    }
}

enum SharedDocumentStore {

    static let appGroup = "group.eu.balzo.pdfexpert"
    /// How many documents the widget may show at most.
    static let maxDocuments = 6

    private static let snapshotName = "widget-documents.json"
    private static let thumbnailsFolder = "widget-thumbnails"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
    }

    private static var snapshotURL: URL? {
        Self.containerURL?.appending(component: Self.snapshotName)
    }

    private static var thumbnailsURL: URL? {
        Self.containerURL?.appending(component: Self.thumbnailsFolder, directoryHint: .isDirectory)
    }

    // MARK: - Reading (app + widget)

    static func load() -> [SharedDocument] {
        guard let url = Self.snapshotURL,
              let data = try? Data(contentsOf: url),
              let documents = try? JSONDecoder().decode([SharedDocument].self, from: data) else {
            return []
        }
        return documents
    }

    static func thumbnail(for document: SharedDocument) -> UIImage? {
        guard let name = document.thumbnailName,
              let url = Self.thumbnailsURL?.appending(component: name),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    // MARK: - Writing (app only)

    /// Replaces the snapshot and its thumbnails. Cheap enough to run on every
    /// archive refresh, but call it off the main thread: it re-encodes images.
    static func save(_ documents: [SharedDocument], thumbnails: [String: UIImage]) {
        guard let containerURL = Self.containerURL, let thumbnailsURL = Self.thumbnailsURL else { return }

        try? FileManager.default.removeItem(at: thumbnailsURL)
        try? FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)

        for (name, image) in thumbnails {
            guard let data = image.pngData() else { continue }
            try? data.write(to: thumbnailsURL.appending(component: name))
        }

        if let data = try? JSONEncoder().encode(documents) {
            try? data.write(to: containerURL.appending(component: Self.snapshotName))
        }
    }
}
