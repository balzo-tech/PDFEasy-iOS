//
//  PdfTitleUtility.swift
//  PdfExpert
//
//  Where the name a document proposes for itself comes from.
//
//  Two sources, in order. The `Title` metadata field when the producer filled it in
//  with something a person would recognise — which is often, and just as often not:
//  exporters write file URLs, "untitled", or "Microsoft Word - contract.docx" into
//  it, so every candidate goes through the same plausibility check as the text does.
//  Failing that, the first page's own typography: the line set in the largest type
//  near the top is the title on an invoice, a contract, a letter and a report alike,
//  which is a far better signal than "the first line" (that is usually a letterhead
//  or a date).
//
//  Nothing here renames anything. It returns a suggestion, and the editor offers it.
//

import Foundation
import PDFKit
import UIKit

enum PdfTitleUtility {

    /// Longest name proposed. Past this a filename stops being a label and starts
    /// being the sentence it was cut from.
    static let maxLength: Int = 60
    /// How far down the first page a title can still be. A letterhead, a logo line
    /// and an address block fit comfortably above it; a body paragraph does not
    /// need to be considered.
    static let maxLinesConsidered: Int = 25

    /// The name this document suggests for itself, or nil when nothing plausible
    /// came out of either source.
    static func suggestedName(for document: PDFDocument) -> String? {
        if let fromMetadata = self.nameFromMetadata(of: document) {
            return fromMetadata
        }
        return self.nameFromFirstPage(of: document)
    }

    // MARK: - Metadata

    static func nameFromMetadata(of document: PDFDocument) -> String? {
        guard let raw = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String else {
            return nil
        }
        return self.cleaned(raw)
    }

    // MARK: - First page

    static func nameFromFirstPage(of document: PDFDocument) -> String? {
        guard let page = document.page(at: 0) else { return nil }
        let candidates = self.candidates(in: page)
        guard !candidates.isEmpty else { return nil }
        // Largest type wins; ties go to whichever came first, which on a page set
        // entirely in one size means the top line — the fallback we would have
        // picked anyway.
        let best = candidates.enumerated().max { left, right in
            if left.element.fontSize == right.element.fontSize {
                return left.offset > right.offset
            }
            return left.element.fontSize < right.element.fontSize
        }
        return best?.element.text
    }

    /// One entry per plausible line of the page's opening, with the largest font
    /// size used anywhere in that line.
    static func candidates(in page: PDFPage) -> [(text: String, fontSize: CGFloat)] {
        guard let attributed = page.attributedString else { return [] }
        let full = attributed.string as NSString
        var result: [(text: String, fontSize: CGFloat)] = []
        var lineStart = 0

        while lineStart < full.length, result.count < Self.maxLinesConsidered {
            let lineRange = full.lineRange(for: NSRange(location: lineStart, length: 0))
            lineStart = NSMaxRange(lineRange)
            guard let text = self.cleaned(full.substring(with: lineRange)) else { continue }
            result.append((text: text, fontSize: Self.largestFontSize(in: attributed, range: lineRange)))
        }
        return result
    }

    private static func largestFontSize(in attributed: NSAttributedString, range: NSRange) -> CGFloat {
        var largest: CGFloat = 0
        attributed.enumerateAttribute(.font, in: range) { value, _, _ in
            guard let font = value as? UIFont else { return }
            largest = max(largest, font.pointSize)
        }
        return largest
    }

    // MARK: - Plausibility and shaping (pure)

    /// Turns a raw line or metadata value into a name worth proposing, or nil when
    /// it is not one. Both sources go through here, because both produce the same
    /// kinds of junk.
    static func cleaned(_ raw: String) -> String? {
        var text = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Producers put the source file in the title field. "Microsoft Word -
        // Rental agreement.docx" is the common shape; the part after the dash is
        // the only useful half.
        if let range = text.range(of: "^Microsoft (Word|PowerPoint|Excel) - ",
                                  options: [.regularExpression, .caseInsensitive]) {
            text = String(text[range.upperBound...])
        }
        text = self.withoutFileExtension(text)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " -–—_·.,;:"))

        // Judged before the illegal characters are stripped, not after: dropping
        // the slashes from a URL or a path first would turn it into something that
        // reads like a perfectly good title.
        guard self.isPlausible(text) else { return nil }

        // Characters a filename cannot carry, and control characters from extraction.
        text = text.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: " ")
            .components(separatedBy: .controlCharacters)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        guard text.count >= 3 else { return nil }
        return self.truncated(text)
    }

    static func isPlausible(_ text: String) -> Bool {
        guard text.count >= 3 else { return false }
        // A line of digits and punctuation is a date, a page number or a rule.
        guard text.rangeOfCharacter(from: .letters) != nil else { return false }
        // Paths and addresses: the title field is full of them.
        let lowercased = text.lowercased()
        guard !lowercased.contains("://"), !lowercased.hasPrefix("www.") else { return false }
        guard !text.hasPrefix("/"), !text.hasPrefix("~/") else { return false }
        guard !Self.placeholders.contains(lowercased) else { return false }
        // A whole paragraph landed on one line: it is body text, not a heading.
        guard text.count <= 140 else { return false }
        guard !Self.looksLikeAFilename(text) else { return false }
        return true
    }

    /// A single run of characters with no spaces, held together by underscores,
    /// dashes or digits — `file-sample_100kB`, `IMG_2026_07_26`, `scan0001`. This is
    /// what producers write into the title field when they have nothing but the
    /// source file's name, and the bundled test document is one of them. A genuine
    /// one-word title (`Contratto`) carries none of those marks, so it survives.
    static func looksLikeAFilename(_ text: String) -> Bool {
        guard !text.contains(" ") else { return false }
        return text.contains("_")
            || text.contains("-")
            || text.rangeOfCharacter(from: .decimalDigits) != nil
    }

    /// Names that carry no information. Kept short on purpose — this is a list of
    /// values producers write when they have nothing, not a stopword list.
    private static let placeholders: Set<String> = [
        "untitled", "untitled document", "document", "documento", "sin título",
        "unknown", "unnamed", "senza titolo", "new document", "scanned document"
    ]

    private static func withoutFileExtension(_ text: String) -> String {
        let known = ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx",
                     "pages", "numbers", "key", "txt", "rtf", "md"]
        let url = URL(fileURLWithPath: text)
        guard known.contains(url.pathExtension.lowercased()) else { return text }
        return url.deletingPathExtension().lastPathComponent
    }

    /// Cuts to `maxLength` on a word boundary, so a proposed name never ends
    /// mid-word.
    static func truncated(_ text: String) -> String {
        guard text.count > Self.maxLength else { return text }
        let cut = text.prefix(Self.maxLength)
        guard let lastSpace = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: lastSpace) >= 20 else {
            return String(cut).trimmingCharacters(in: .whitespaces)
        }
        return String(cut[..<lastSpace]).trimmingCharacters(in: CharacterSet(charactersIn: " -–—_·.,;:"))
    }
}
