//
//  PdfScanUtility.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/05/23.
//
//  Turns finished scan pages into a PDF.
//
//  A scanned page gets a page box of its own proportions rather than being
//  letterboxed onto a fixed A4 sheet the way `UIImage.pdfPage()` does: a receipt
//  should come out receipt-shaped, and a page shot at 4:3 should not carry two
//  white bands it never had. The long side is scaled to A4's, so a stack of
//  scans still prints and reads at a familiar size.
//

import Foundation
import SwiftUI
import PDFKit

enum PdfScanUtility {

    /// Builds the document, reporting progress page by page.
    ///
    /// Synchronous and free of UI: the callers decide which queue it runs on,
    /// and the unit tests call it directly.
    static func makeDocument(from pages: [ScannedPage],
                             onProgress: ((Int) -> Void)? = nil) -> PDFDocument {
        let document = PDFDocument()
        for (index, page) in pages.enumerated() {
            if let pdfPage = self.pdfPage(for: page) {
                document.insert(pdfPage, at: document.pageCount)
            }
            onProgress?(index + 1)
        }
        return document
    }

    /// One rendered, straightened, filtered page.
    static func pdfPage(for page: ScannedPage) -> PDFPage? {
        guard let image = ScanImageProcessor.render(page, maxDimension: K.Misc.ScanPageMaxDimension) else {
            return nil
        }
        return self.pdfPage(for: image)
    }

    static func pdfPage(for image: UIImage) -> PDFPage? {
        let bounds = self.pageBounds(forImageSize: image.size)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        // Drawing into a renderer, rather than `PDFPage(image:)`, is what the
        // rest of the app does — see the note on `UIImage.pdfPage()`: pages
        // built the other way redraw black once they are annotated.
        let data = renderer.pdfData { context in
            context.beginPage()
            context.cgContext.interpolationQuality = .high
            image.draw(in: bounds)
        }
        return PDFDocument(data: data)?.page(at: 0)
    }

    /// A page box with the image's proportions, scaled so its longest side
    /// matches A4's longest side.
    static func pageBounds(forImageSize size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: K.Misc.PdfPageSize)
        }
        let referenceLongSide = max(K.Misc.PdfPageSize.width, K.Misc.PdfPageSize.height)
        let scale = referenceLongSide / max(size.width, size.height)
        return CGRect(origin: .zero,
                      size: CGSize(width: (size.width * scale).rounded(),
                                   height: (size.height * scale).rounded()))
    }

    /// Drives an `AsyncOperation` binding, the way the rest of the import flows
    /// do, so the caller gets a progress bar for free.
    static func convertScan(pages: [ScannedPage],
                            filename: String? = nil,
                            source: PdfSource = .scan,
                            asyncOperation: Binding<AsyncOperation<Pdf, PdfError>>) {

        let progress = Progress(totalUnitCount: Int64(pages.count))
        asyncOperation.wrappedValue = AsyncOperation(status: .loading(progress))

        DispatchQueue.global(qos: .userInitiated).async {
            let document = self.makeDocument(from: pages) { completed in
                DispatchQueue.main.async {
                    progress.completedUnitCount = Int64(completed)
                    asyncOperation.wrappedValue = AsyncOperation(status: .loading(progress))
                }
            }

            DispatchQueue.main.async {
                guard document.pageCount > 0 else {
                    asyncOperation.wrappedValue = AsyncOperation(status: .error(.unknownError))
                    return
                }
                let pdf = Pdf(pdfDocument: document,
                              filename: filename ?? Self.defaultFilename(),
                              source: source)
                asyncOperation.wrappedValue = AsyncOperation(status: .data(pdf))
            }
        }
    }

    /// The name a scan is offered before the user types one: dated and timed, so
    /// a morning of scanning does not produce ten documents called the same
    /// thing. Deliberately not localized — it ends up as a filename.
    static func defaultFilename(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Scan \(formatter.string(from: date))"
    }
}
