//
//  ArchiveIndexer.swift
//  PdfExpert
//
//  Reads a document after it has been saved, so the archive can find it again.
//
//  `CDPdf.update` indexes what PDFKit can extract, which is the right answer for
//  a PDF that carries text and no answer at all for the ones this app actually
//  makes: six documents out of ten are built from photographs, and a photograph
//  has no text layer. Those documents went into the archive unsearchable and
//  named `File-09-17-2026`.
//
//  So the words are recognized here instead — on-device, off the saving path,
//  and without touching the document itself: the file the user made is not
//  changed by having been read. What comes back is an index, and, while the
//  document is still carrying the name the app generated for it, a name.
//

import Foundation
import PDFKit
import Factory

extension Container {
    var archiveIndexer: Factory<ArchiveIndexer> {
        self { ArchiveIndexer() }.singleton
    }
}

class ArchiveIndexer {

    /// How far into a document the index reaches. An index is for finding a file
    /// again, and what people remember is the beginning of it.
    static let pageLimit: Int = 10

    /// A candidate title has to be long enough to mean something and short enough
    /// to read in a list.
    private static let titleLengthRange: ClosedRange<Int> = 3...60

    /// Characters a filename cannot carry, plus the ones that only look like
    /// noise once a line of a scanned form ends up as a title.
    private static let illegalFilenameCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")

    @Injected(\.analyticsManager) private var analyticsManager

    /// Documents being read right now. Every edit saves, and saving is what asks
    /// for an index — without this, a document edited three times in a row would
    /// be recognized three times over.
    private var inFlight: Set<String> = []
    private let inFlightLock = NSLock()

    /// Fire and forget: the caller has just saved and must not wait for Vision.
    ///
    /// The store arrives as an argument rather than through the container: the
    /// repository is what asks for an index, and injecting it back here is a
    /// dependency cycle Factory refuses to resolve.
    func indexIfNeeded(pdf: Pdf, storingWith repository: Repository) {
        guard pdf.storeId != nil,
              (pdf.searchableText ?? "").isEmpty,
              pdf.pageCount > 0,
              let data = pdf.rawData else { return }

        let documentId = pdf.documentId
        guard self.beginIndexing(documentId) else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            defer { self.endIndexing(documentId) }

            // Rebuilt from the bytes rather than shared: `PDFDocument` is not
            // thread-safe, and the one in `pdf` belongs to whatever screen is
            // holding it.
            guard let document = PDFDocument(data: data) else { return }
            let text = OcrUtility.recognizedText(from: document, pageLimit: Self.pageLimit)
            guard !text.isEmpty else { return }

            let filename = Self.suggestedFilename(from: text, currentFilename: pdf.filename)
            await self.store(text: text, filename: filename, for: pdf, in: repository)
        }
    }

    @MainActor
    private func store(text: String, filename: String?, for pdf: Pdf, in repository: Repository) {
        do {
            _ = try repository.applyIndex(searchableText: text, filename: filename, for: pdf)
            self.analyticsManager.track(event: .documentIndexed)
            if filename != nil {
                self.analyticsManager.track(event: .documentAutoNamed)
            }
        } catch {
            // A document deleted while it was being read is the normal case here,
            // and there is nothing to tell anyone about it.
            debugPrint(for: self, message: "Could not store the index. Error: \(error)")
        }
    }

    // MARK: - Naming

    /// A name for a document that has not been named. Returns nil when the user
    /// has already called it something — a document called something is called
    /// that on purpose — or when nothing in the text reads like a title.
    static func suggestedFilename(from text: String, currentFilename: String) -> String? {
        guard Pdf.isGeneratedFilename(currentFilename) else { return nil }
        for line in text.components(separatedBy: .newlines) {
            guard let candidate = Self.title(from: line) else { continue }
            return candidate
        }
        return nil
    }

    /// One line of recognized text, judged as a title: stripped of what a
    /// filename cannot hold, long enough to be a name, and carrying actual
    /// words rather than a date, a total or a page number.
    private static func title(from line: String) -> String? {
        let cleaned = line
            .components(separatedBy: Self.illegalFilenameCharacters)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-–—_·•"))
            .trimmingCharacters(in: .whitespaces)

        guard Self.titleLengthRange.contains(cleaned.count) else { return nil }
        let letters = cleaned.filter { $0.isLetter }
        guard letters.count >= 3 else { return nil }
        // More digits than letters is a date, an amount or an invoice number —
        // the top line of a receipt, and a bad name for it. Counted against the
        // letters rather than against the whole line, so `ISEE 2026` survives
        // and `12/09/2026 450,00` does not.

        guard cleaned.filter({ $0.isNumber }).count <= letters.count else { return nil }

        // A form shouting its heading in capitals becomes a title, not a shout —
        // but only when there are more letters in it than any acronym has. `ISEE
        // 2026` keeps its capitals, `MEDICAL CERTIFICATE` does not.
        let isAllCaps = cleaned == cleaned.uppercased()
        return isAllCaps && letters.count > 8 ? cleaned.localizedCapitalized : cleaned
    }

    // MARK: - In-flight bookkeeping

    private func beginIndexing(_ documentId: String) -> Bool {
        self.inFlightLock.lock()
        defer { self.inFlightLock.unlock() }
        return self.inFlight.insert(documentId).inserted
    }

    private func endIndexing(_ documentId: String) {
        self.inFlightLock.lock()
        self.inFlight.remove(documentId)
        self.inFlightLock.unlock()
    }
}
