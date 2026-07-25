//
//  PdfCompareViewModel.swift
//  PdfExpert
//
//  "Compare PDFs" (PREMIUM): pick two documents, get what changed between them.
//
//  Nothing is written: comparing is a read-only answer, so there is no document to
//  save and no way for the tool to damage either input.
//

import Foundation
import Factory
import SwiftUI
import PDFKit

extension Container {
    var pdfCompareViewModel: Factory<PdfCompareViewModel> {
        self { PdfCompareViewModel() }
    }
}

/// Which of the two documents the running import is filling.
enum CompareSlot {
    case left, right
}

class PdfCompareViewModel: ObservableObject {

    @Published var setupShow: Bool = false
    @Published var monetizationShow: Bool = false
    @Published var resultShow: Bool = false

    @Published private(set) var leftPdf: Pdf? = nil
    @Published private(set) var rightPdf: Pdf? = nil
    @Published private(set) var result: PdfCompareResult? = nil
    @Published private(set) var isComparing: Bool = false
    @Published private(set) var progress: Double = 0

    @Published var asyncImportedPdf: AsyncOperation<Pdf, PdfError> = AsyncOperation(status: .empty) {
        didSet {
            if let importedPdf = self.asyncImportedPdf.data {
                self.onImportCompleted(pdf: importedPdf)
                self.asyncImportedPdf = .init(status: .empty)
            }
        }
    }
    @Published var asyncCompare: AsyncEmptyFailable<SharedLocalizedError> = .idle

    var canCompare: Bool { self.leftPdf != nil && self.rightPdf != nil && !self.isComparing }

    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.store) private var store

    lazy var pdfImportViewModel: PdfImportViewModel = {
        Container.shared.pdfImportViewModel(PdfImportViewModel.Params(asyncPdf: self.asyncSubject(\.asyncImportedPdf)))
    }()

    private var pendingSlot: CompareSlot = .left
    private var onCompleted: (() -> ())? = nil

    @MainActor
    func run(pdf: Pdf?, onCompleted: (() -> ())?) {
        self.onCompleted = onCompleted
        self.leftPdf = pdf
        self.rightPdf = nil
        self.result = nil
        self.analyticsManager.track(event: .reportScreen(.compare))
        self.setupShow = true
    }

    // MARK: - Choosing the two documents

    @MainActor
    func pickDocument(for slot: CompareSlot) {
        self.pendingSlot = slot
        self.pdfImportViewModel.importPdf(importFileTypes: K.Misc.ImportFileTypesForExtract)
    }

    private func onImportCompleted(pdf: Pdf) {
        guard pdf.pageCount > 0 else {
            self.asyncCompare = .error(.unknownError)
            return
        }
        switch self.pendingSlot {
        case .left: self.leftPdf = pdf
        case .right: self.rightPdf = pdf
        }
    }

    // MARK: - Premium gate

    @MainActor
    func requestCompare() {
        guard self.canCompare else { return }
        if self.store.isPremium.value {
            self.compare()
        } else {
            self.monetizationShow = true
        }
    }

    @MainActor
    func onMonetizationClose() {
        guard self.store.isPremium.value else { return }
        self.compare()
    }

    // MARK: - Comparison

    @MainActor
    private func compare() {
        guard let left = self.leftPdf?.pdfDocument, let right = self.rightPdf?.pdfDocument else { return }
        self.isComparing = true
        self.progress = 0
        self.analyticsManager.track(event: .compareStarted)

        DispatchQueue.global(qos: .userInitiated).async {
            let result = PdfCompareUtility.compare(left: left, right: right) { fraction in
                DispatchQueue.main.async { self.progress = fraction }
            }
            DispatchQueue.main.async {
                self.isComparing = false
                self.result = result
                self.setupShow = false
                self.resultShow = true
                self.analyticsManager.track(event: .compareCompleted(changedPageCount: result.changedPages.count))
            }
        }
    }

    // MARK: - Page rendering for the visual diff

    /// Renders one side of an aligned pair, or nil when that side has no such page
    /// (an insertion or a deletion).
    func pageImage(for comparison: PageComparison, side: CompareSlot, width: CGFloat) -> UIImage? {
        let document = side == .left ? self.leftPdf?.pdfDocument : self.rightPdf?.pdfDocument
        let index = side == .left ? comparison.leftPageIndex : comparison.rightPageIndex
        guard let document, let index, let page = document.page(at: index) else { return nil }

        let bounds = page.bounds(for: .mediaBox)
        let isQuarterTurned = abs(page.rotation) % 180 != 0
        let size = isQuarterTurned
            ? CGSize(width: bounds.height, height: bounds.width)
            : bounds.size
        guard size.width > 0 else { return nil }
        let height = width / size.width * size.height
        return page.thumbnail(of: CGSize(width: width, height: height), for: .mediaBox)
    }

    #if DEBUG
    /// Runs the tool on two synthetic contracts, one edited, so the result screen
    /// can be inspected on a simulator — where the file picker cannot be driven
    /// and the paywall would block the run anyway.
    ///   xcrun simctl spawn booted defaults write <bundle-id> debugRunTool -string compare
    @MainActor
    func debugRunWithSampleDocuments() {
        let shared = ["RENTAL AGREEMENT",
                      "Between the landlord and the tenant.",
                      "The tenant agrees to keep the property in good order."]
        let left = Self.debugDocument(pages: [shared + ["Rent is 900 euro per month.",
                                                        "Deposit: two months."],
                                              ["Annex A", "Inventory of the furniture."]])
        let right = Self.debugDocument(pages: [shared + ["Rent is 1200 euro per month.",
                                                         "Deposit: three months.",
                                                         "Payment is due on the first working day."]])
        guard let left, let right else { return }
        self.leftPdf = Pdf(pdfDocument: left)
        self.rightPdf = Pdf(pdfDocument: right)
        self.setupShow = true
        self.compare()
    }

    private static func debugDocument(pages: [[String]]) -> PDFDocument? {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for lines in pages {
                context.beginPage()
                for (index, line) in lines.enumerated() {
                    (line as NSString).draw(at: CGPoint(x: 48, y: 60 + CGFloat(index) * 42),
                                            withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
                }
            }
        }
        return PDFDocument(data: data)
    }
    #endif

    @MainActor
    func closeResult() {
        self.resultShow = false
        self.result = nil
        self.leftPdf = nil
        self.rightPdf = nil
        self.onCompleted?()
    }

    @MainActor
    func cancel() {
        self.setupShow = false
        self.leftPdf = nil
        self.rightPdf = nil
        self.result = nil
    }
}
