//
//  PdfPermissionsUtility.swift
//  PdfExpert
//
//  Sets the PDF permission flags (printing, copying) on a document.
//
//  PDFKit cannot do this: `PDFDocumentWriteOption` only carries user/owner passwords,
//  which is all `PDFUtility.processToShare` uses. Permissions live in the encryption
//  dictionary, so the document has to be re-emitted through a `CGPDFContext` with the
//  flags in its auxiliary info. `drawPDFPage` copies page content as-is, so text stays
//  vector and selectable.
//
//  Two things worth knowing, both surfaced to the user rather than hidden:
//   * The flags are ignored without an **owner password** — that password is what makes
//     them enforceable, so it is required here.
//   * `allowsCopying = false` is a convention viewers choose to honor, not encryption.
//     Text can still be extracted by tools that ignore it; this is not a secrecy feature.
//

import Foundation
import UIKit
import PDFKit

struct PdfPermissions: Equatable {
    var allowsPrinting: Bool = true
    var allowsCopying: Bool = true
}

class PdfPermissionsUtility {

    /// Re-emits `document` with the given permissions, returning the encrypted bytes.
    ///
    /// - Parameters:
    ///   - ownerPassword: required; without it the flags carry no weight and this
    ///     returns nil rather than silently producing an unprotected file.
    ///   - userPassword: optional. When nil the document still opens without a
    ///     password — only the permissions are restricted.
    static func apply(to document: PDFDocument,
                      ownerPassword: String,
                      userPassword: String? = nil,
                      permissions: PdfPermissions) -> Data? {

        let owner = ownerPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty else { return nil }
        // Checked on the PDFDocument, not on the CGPDFDocument below: PDFKit serializes
        // an empty document into one blank page, which would otherwise be "protected"
        // and saved to the archive as a file the user never had.
        guard document.pageCount > 0 else { return nil }

        guard let sourceData = document.dataRepresentation(),
              let provider = CGDataProvider(data: sourceData as CFData),
              let sourceDocument = CGPDFDocument(provider),
              sourceDocument.numberOfPages > 0 else { return nil }

        let outputData = NSMutableData()
        guard let consumer = CGDataConsumer(data: outputData as CFMutableData) else { return nil }

        var auxiliaryInfo: [CFString: Any] = [
            kCGPDFContextOwnerPassword: owner,
            kCGPDFContextAllowsPrinting: permissions.allowsPrinting,
            kCGPDFContextAllowsCopying: permissions.allowsCopying
        ]
        if let userPassword = userPassword,
           !userPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            auxiliaryInfo[kCGPDFContextUserPassword] = userPassword
        }

        guard let context = CGContext(consumer: consumer,
                                      mediaBox: nil,
                                      auxiliaryInfo as CFDictionary) else { return nil }

        for pageNumber in 1...sourceDocument.numberOfPages {
            guard let page = sourceDocument.page(at: pageNumber) else { continue }

            let mediaBox = page.getBoxRect(.mediaBox)
            // /Rotate is a page attribute that does not survive `drawPDFPage`, so the
            // output box is the rotated one and the rotation is baked into the drawing
            // transform. Without this, a landscape (90°-rotated) page comes out portrait
            // and clipped.
            let isQuarterTurned = abs(page.rotationAngle) % 180 != 0
            var targetBox = isQuarterTurned
                ? CGRect(x: 0, y: 0, width: mediaBox.height, height: mediaBox.width)
                : CGRect(x: 0, y: 0, width: mediaBox.width, height: mediaBox.height)

            context.beginPage(mediaBox: &targetBox)
            context.saveGState()
            // `getDrawingTransform` accounts for the page's own rotation.
            context.concatenate(page.getDrawingTransform(.mediaBox,
                                                         rect: targetBox,
                                                         rotate: 0,
                                                         preserveAspectRatio: true))
            context.drawPDFPage(page)
            context.restoreGState()
            context.endPage()
        }
        context.closePDF()

        return outputData as Data
    }
}
