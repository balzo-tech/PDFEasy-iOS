//
//  PdfCompareUtility.swift
//  PdfExpert
//
//  "Compare PDFs" (PREMIUM): what changed between two versions of a document.
//
//  Two answers are needed, because neither is enough on its own. The **text**
//  diff says what words were added or removed — useless on a scan, essential on a
//  contract. The **visual** diff says which areas of the page look different —
//  blind to wording, but the only one that catches a moved logo, a new stamp or a
//  signature, and the only one that works at all when the pages carry no text.
//
//  Pages are aligned before anything is compared: inserting a page at the front
//  must not report every later page as rewritten. The alignment is an LCS over
//  page text, falling back to position when the documents carry no text to align
//  on (two scans).
//

import Foundation
import UIKit
import PDFKit

struct TextChange: Identifiable, Equatable {

    enum Kind { case added, removed }

    let id = UUID()
    let kind: Kind
    let text: String

    static func == (lhs: TextChange, rhs: TextChange) -> Bool {
        lhs.kind == rhs.kind && lhs.text == rhs.text
    }
}

/// One aligned pair of pages. A nil index means the page exists only in the other
/// document — an insertion or a deletion, not a modification.
struct PageComparison: Identifiable {

    let id = UUID()
    let leftPageIndex: Int?
    let rightPageIndex: Int?
    let textChanges: [TextChange]
    /// 0…1 of the page area that renders differently.
    let changedAreaFraction: Double
    /// Row-major grid of changed cells, `visualGridColumns` wide. Lets the UI draw
    /// the highlight over a freshly rendered page instead of shipping bitmaps.
    let changedCells: [Bool]
    let visualGridColumns: Int

    var isAdded: Bool { self.leftPageIndex == nil }
    var isRemoved: Bool { self.rightPageIndex == nil }
    var hasChanges: Bool {
        self.isAdded || self.isRemoved || !self.textChanges.isEmpty || self.changedAreaFraction > 0
    }
}

struct PdfCompareResult {

    let pages: [PageComparison]

    var changedPages: [PageComparison] { self.pages.filter { $0.hasChanges } }
    var hasDifferences: Bool { !self.changedPages.isEmpty }
    var addedPageCount: Int { self.pages.filter { $0.isAdded }.count }
    var removedPageCount: Int { self.pages.filter { $0.isRemoved }.count }
}

class PdfCompareUtility {

    /// Cells across the page for the visual diff. 32 columns on an A4 is roughly a
    /// 19 pt cell: fine enough to point at a changed line, coarse enough that
    /// anti-aliasing noise does not light up the page.
    static let visualGridColumns = 32
    /// A cell counts as changed when its mean absolute difference exceeds this
    /// (0…255). Below ~10 it fires on re-rendering noise alone.
    static let visualCellThreshold: Double = 12
    /// Words above which the text diff drops to line granularity: the LCS matrix
    /// is quadratic and a dense page is not worth minutes of CPU.
    static let maxWordsForWordDiff = 1500

    static func compare(left: PDFDocument,
                        right: PDFDocument,
                        progress: ((Double) -> Void)? = nil) -> PdfCompareResult {

        let alignment = self.alignPages(left: left, right: right)
        var comparisons: [PageComparison] = []

        for (index, pair) in alignment.enumerated() {
            defer { progress?(Double(index + 1) / Double(max(alignment.count, 1))) }

            let leftPage = pair.left.flatMap { left.page(at: $0) }
            let rightPage = pair.right.flatMap { right.page(at: $0) }

            // A page that exists on one side only is reported as such: diffing it
            // against nothing would just list its entire text as added.
            guard let leftPage, let rightPage else {
                comparisons.append(PageComparison(leftPageIndex: pair.left,
                                                  rightPageIndex: pair.right,
                                                  textChanges: [],
                                                  changedAreaFraction: pair.left == nil || pair.right == nil ? 1 : 0,
                                                  changedCells: [],
                                                  visualGridColumns: self.visualGridColumns))
                continue
            }

            let textChanges = self.textDiff(left: leftPage.string ?? "", right: rightPage.string ?? "")
            let visual = self.visualDiff(left: leftPage, right: rightPage)
            comparisons.append(PageComparison(leftPageIndex: pair.left,
                                              rightPageIndex: pair.right,
                                              textChanges: textChanges,
                                              changedAreaFraction: visual.fraction,
                                              changedCells: visual.cells,
                                              visualGridColumns: self.visualGridColumns))
        }
        return PdfCompareResult(pages: comparisons)
    }

    // MARK: - Page alignment

    struct PagePair {
        let left: Int?
        let right: Int?
    }

    /// Matches pages by their text through an LCS, so an inserted or deleted page
    /// shifts nothing else. Falls back to positional pairing when there is not
    /// enough text to align on — two scans have no signature to match.
    static func alignPages(left: PDFDocument, right: PDFDocument) -> [PagePair] {
        let leftKeys = (0..<left.pageCount).map { self.signature(of: left.page(at: $0)) }
        let rightKeys = (0..<right.pageCount).map { self.signature(of: right.page(at: $0)) }

        let textPages = leftKeys.filter { !$0.isEmpty }.count + rightKeys.filter { !$0.isEmpty }.count
        let totalPages = leftKeys.count + rightKeys.count
        guard totalPages > 0 else { return [] }

        guard Double(textPages) / Double(totalPages) >= 0.5 else {
            return self.positionalAlignment(leftCount: leftKeys.count, rightCount: rightKeys.count)
        }
        // The LCS matches pages that are *identical*; an edited page therefore
        // comes out as one removal plus one insertion. Re-pairing the similar ones
        // is what turns that back into "this page changed".
        return self.pairSimilarPages(self.lcsAlignment(leftKeys, rightKeys),
                                     leftKeys: leftKeys,
                                     rightKeys: rightKeys)
    }

    /// How alike two pages have to read to count as the same page, edited, rather
    /// than as one page replaced by another. Jaccard over their words: 0.4 keeps a
    /// rewritten paragraph together while a genuinely different page stays apart.
    static let pageSimilarityThreshold: Double = 0.4

    /// Walks the runs of unmatched pages and pairs them up in order when they are
    /// similar enough.
    private static func pairSimilarPages(_ alignment: [PagePair],
                                         leftKeys: [String],
                                         rightKeys: [String]) -> [PagePair] {
        var result: [PagePair] = []
        var pendingLeft: [Int] = []
        var pendingRight: [Int] = []

        func flushPending() {
            var leftIndex = 0
            var rightIndex = 0
            while leftIndex < pendingLeft.count && rightIndex < pendingRight.count {
                let left = pendingLeft[leftIndex]
                let right = pendingRight[rightIndex]
                if self.similarity(leftKeys[left], rightKeys[right]) >= self.pageSimilarityThreshold {
                    result.append(PagePair(left: left, right: right))
                    leftIndex += 1
                    rightIndex += 1
                } else {
                    // Not the same page: report the removal, then look at the next
                    // one against the same candidate on the right.
                    result.append(PagePair(left: left, right: nil))
                    leftIndex += 1
                }
            }
            while leftIndex < pendingLeft.count {
                result.append(PagePair(left: pendingLeft[leftIndex], right: nil))
                leftIndex += 1
            }
            while rightIndex < pendingRight.count {
                result.append(PagePair(left: nil, right: pendingRight[rightIndex]))
                rightIndex += 1
            }
            pendingLeft = []
            pendingRight = []
        }

        for pair in alignment {
            switch (pair.left, pair.right) {
            case (let left?, nil): pendingLeft.append(left)
            case (nil, let right?): pendingRight.append(right)
            default:
                flushPending()
                result.append(pair)
            }
        }
        flushPending()
        return result
    }

    /// Jaccard similarity over the words of two page signatures.
    static func similarity(_ left: String, _ right: String) -> Double {
        let leftWords = Set(left.components(separatedBy: " ").filter { !$0.isEmpty })
        let rightWords = Set(right.components(separatedBy: " ").filter { !$0.isEmpty })
        guard !leftWords.isEmpty || !rightWords.isEmpty else { return 1 }
        let union = leftWords.union(rightWords).count
        guard union > 0 else { return 1 }
        return Double(leftWords.intersection(rightWords).count) / Double(union)
    }

    private static func positionalAlignment(leftCount: Int, rightCount: Int) -> [PagePair] {
        (0..<max(leftCount, rightCount)).map { index in
            PagePair(left: index < leftCount ? index : nil,
                     right: index < rightCount ? index : nil)
        }
    }

    /// Normalized page text used as the matching key: case and spacing differences
    /// must not make two identical pages look different.
    private static func signature(of page: PDFPage?) -> String {
        guard let text = page?.string else { return "" }
        return text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Text diff

    /// Word-level added/removed runs. Consecutive words of the same kind are
    /// joined, so the UI shows "the tenant agrees" rather than three entries.
    static func textDiff(left: String, right: String) -> [TextChange] {
        let leftWords = self.words(in: left)
        let rightWords = self.words(in: right)
        guard leftWords != rightWords else { return [] }

        // Too dense for a word matrix (it is quadratic): compare whole lines.
        if leftWords.count * rightWords.count > self.maxWordsForWordDiff * self.maxWordsForWordDiff {
            let leftLines = self.lines(in: left)
            let rightLines = self.lines(in: right)
            return self.changes(from: self.lcsAlignment(leftLines, rightLines),
                                left: leftLines,
                                right: rightLines)
        }
        return self.changes(from: self.lcsAlignment(leftWords, rightWords),
                            left: leftWords,
                            right: rightWords)
    }

    private static func changes(from alignment: [PagePair],
                                left: [String],
                                right: [String]) -> [TextChange] {
        var changes: [TextChange] = []
        var pendingKind: TextChange.Kind? = nil
        var pendingWords: [String] = []

        func flush() {
            if let kind = pendingKind, !pendingWords.isEmpty {
                changes.append(TextChange(kind: kind, text: pendingWords.joined(separator: " ")))
            }
            pendingKind = nil
            pendingWords = []
        }

        for pair in alignment {
            switch (pair.left, pair.right) {
            case (let leftIndex?, nil):
                if pendingKind != .removed { flush() }
                pendingKind = .removed
                pendingWords.append(left[leftIndex])
            case (nil, let rightIndex?):
                if pendingKind != .added { flush() }
                pendingKind = .added
                pendingWords.append(right[rightIndex])
            default:
                flush()
            }
        }
        flush()
        return changes
    }

    private static func words(in text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }

    private static func lines(in text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - LCS

    /// Longest common subsequence, returned as an alignment: matched elements
    /// carry both indices, unmatched ones only their own side.
    static func lcsAlignment<T: Equatable>(_ left: [T], _ right: [T]) -> [PagePair] {
        let leftCount = left.count
        let rightCount = right.count
        guard leftCount > 0 else { return (0..<rightCount).map { PagePair(left: nil, right: $0) } }
        guard rightCount > 0 else { return (0..<leftCount).map { PagePair(left: $0, right: nil) } }

        // lengths[i][j] = LCS length of left[i...] and right[j...]
        var lengths = [[Int]](repeating: [Int](repeating: 0, count: rightCount + 1), count: leftCount + 1)
        for i in stride(from: leftCount - 1, through: 0, by: -1) {
            for j in stride(from: rightCount - 1, through: 0, by: -1) {
                lengths[i][j] = left[i] == right[j]
                    ? lengths[i + 1][j + 1] + 1
                    : max(lengths[i + 1][j], lengths[i][j + 1])
            }
        }

        var alignment: [PagePair] = []
        var i = 0
        var j = 0
        while i < leftCount && j < rightCount {
            if left[i] == right[j] {
                alignment.append(PagePair(left: i, right: j))
                i += 1
                j += 1
            } else if lengths[i + 1][j] >= lengths[i][j + 1] {
                alignment.append(PagePair(left: i, right: nil))
                i += 1
            } else {
                alignment.append(PagePair(left: nil, right: j))
                j += 1
            }
        }
        while i < leftCount {
            alignment.append(PagePair(left: i, right: nil))
            i += 1
        }
        while j < rightCount {
            alignment.append(PagePair(left: nil, right: j))
            j += 1
        }
        return alignment
    }

    // MARK: - Visual diff

    /// Renders both pages to the same grayscale raster and reports which cells of
    /// a coarse grid differ. Both pages are normalized to the *left* page's aspect
    /// ratio: comparing a portrait against a landscape pixel by pixel is
    /// meaningless, and the grid difference will say so anyway.
    static func visualDiff(left: PDFPage, right: PDFPage) -> (fraction: Double, cells: [Bool]) {
        let leftSize = self.displaySize(of: left)
        guard leftSize.width > 0, leftSize.height > 0 else { return (0, []) }

        let columns = self.visualGridColumns
        let cellSide = 16
        let width = columns * cellSide
        let rows = max(Int((leftSize.height / leftSize.width * CGFloat(columns)).rounded()), 1)
        let height = rows * cellSide

        guard let leftPixels = self.grayscalePixels(of: left, width: width, height: height),
              let rightPixels = self.grayscalePixels(of: right, width: width, height: height) else {
            return (0, [])
        }

        var cells = [Bool](repeating: false, count: columns * rows)
        var changedCount = 0
        for row in 0..<rows {
            for column in 0..<columns {
                var total = 0
                for y in (row * cellSide)..<((row + 1) * cellSide) {
                    let rowOffset = y * width
                    for x in (column * cellSide)..<((column + 1) * cellSide) {
                        let index = rowOffset + x
                        total += abs(Int(leftPixels[index]) - Int(rightPixels[index]))
                    }
                }
                let mean = Double(total) / Double(cellSide * cellSide)
                if mean > self.visualCellThreshold {
                    cells[row * columns + column] = true
                    changedCount += 1
                }
            }
        }
        return (Double(changedCount) / Double(cells.count), cells)
    }

    private static func displaySize(of page: PDFPage) -> CGSize {
        let mediaBox = page.bounds(for: .mediaBox)
        return abs(page.rotation) % 180 != 0
            ? CGSize(width: mediaBox.height, height: mediaBox.width)
            : mediaBox.size
    }

    private static func grayscalePixels(of page: PDFPage, width: Int, height: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 255, count: width * height)
        guard let context = CGContext(data: &pixels,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }

        // White background: a PDF page paints nothing where it has no content.
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let pageSize = self.displaySize(of: page)
        guard pageSize.width > 0, pageSize.height > 0 else { return pixels }
        context.saveGState()
        context.scaleBy(x: CGFloat(width) / pageSize.width, y: CGFloat(height) / pageSize.height)
        // No flip on purpose: a bitmap context's rows start at the top while its
        // coordinate space starts at the bottom, so drawing the page as-is already
        // puts the top of the page in row 0 — which is the order the grid, and the
        // overlay drawn from it, are read in.
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        return pixels
    }
}
