//
//  PdfUtility.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 06/04/23.
//

import Foundation
import PDFKit
import CoreData

class PDFUtility {
    
    static func convertUiImageToPdf(uiImage: UIImage) -> PDFDocument {
        let pdfDocument = PDFDocument()
        appendImageToPdfDocument(pdfDocument: pdfDocument, uiImage: uiImage)
        return pdfDocument
    }
    
    static func appendImageToPdfDocument(pdfDocument: PDFDocument, uiImage: UIImage) {
        
        if let pdfPage = uiImage.pdfPage() {
            pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
        } else {
            assertionFailure("Couldn't create pdf page from given UIImage")
        }
    }
    
    static func appendPdfDocument(_ pdfDocument: PDFDocument, toPdfDocument: PDFDocument) {
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                toPdfDocument.insert(page, at: toPdfDocument.pageCount)
            } else {
                assertionFailure("Missing expected page at index: \(pageIndex)")
            }
        }
    }

    /// Builds ONE new document holding the pages covered by `pageRanges`, inserted in
    /// the given range order. This is the "extract" counterpart to split's per-range
    /// slicing: instead of one document per range, all ranges are concatenated into a
    /// single output. Overlapping ranges duplicate the shared pages. Ranges are 0-based,
    /// inclusive page indexes, the same convention `PdfSplitViewModel` uses.
    static func extractPages(fromDocument document: PDFDocument, pageRanges: [ClosedRange<Int>]) -> PDFDocument {
        let newDocument = PDFDocument()
        let sourceData = document.dataRepresentation()

        // A page object can live at only one index of one document, so overlapping ranges
        // need distinct objects for the duplicated pages. `PDFPage.copy()` produces such
        // objects but its text isn't extractable in isolation (the font/resource refs
        // aren't self-contained). Instead we source each occurrence from an independent
        // clone of the document reloaded from its serialized data — those page objects are
        // self-contained. Clones are created lazily, one per duplication "generation", so a
        // document with no overlaps only ever parses a single clone.
        var sourceClones: [PDFDocument] = []
        var occurrenceCount: [Int: Int] = [:]
        func clone(_ generation: Int) -> PDFDocument {
            while sourceClones.count <= generation {
                sourceClones.append(sourceData.flatMap { PDFDocument(data: $0) } ?? document)
            }
            return sourceClones[generation]
        }

        for pageRange in pageRanges {
            for pageIndex in pageRange {
                guard pageIndex >= 0, pageIndex < document.pageCount else {
                    assertionFailure("Missing expected page at index: \(pageIndex)")
                    continue
                }
                let generation = occurrenceCount[pageIndex, default: 0]
                occurrenceCount[pageIndex] = generation + 1
                if let page = clone(generation).page(at: pageIndex) {
                    newDocument.insert(page, at: newDocument.pageCount)
                } else {
                    assertionFailure("Missing expected page at index: \(pageIndex)")
                }
            }
        }

        // Round-trip so the result is fully self-contained: the inserted pages reference
        // the source clones, which are released when this method returns. Serializing now
        // (while they're alive) and reloading keeps text/rendering intact afterwards,
        // mirroring `applyPostProcess`.
        return newDocument.dataRepresentation().flatMap { PDFDocument(data: $0) } ?? newDocument
    }
    
    /// Rotates a page by a quarter turn, normalizing the result into the [0, 360) range.
    /// The rotation is stored in the page's /Rotate entry, so it survives serialization.
    static func rotatePage(_ page: PDFPage, clockwise: Bool) {
        page.rotation = (((page.rotation + (clockwise ? 90 : -90)) % 360) + 360) % 360
    }

    static func generatePdfThumbnails(pdfDocument: PDFDocument, size: CGSize?) -> [UIImage?] {
        var thumbnails: [UIImage?] = []
        for index in 0..<pdfDocument.pageCount {
            let image = Self.generatePdfThumbnail(pdfDocument: pdfDocument,
                                                  size: size,
                                                  forPageIndex: index)
            thumbnails.append(image)
        }
        return thumbnails
    }
    
    static func generatePdfThumbnail(documentData: Data,
                                     size: CGSize?,
                                     forPageIndex pageIndex: Int = 0) -> UIImage? {
        guard let pdfDocument = PDFDocument(data: documentData) else { return nil }
        return self.generatePdfThumbnail(pdfDocument: pdfDocument,
                                         size: size,
                                         forPageIndex: pageIndex)
    }
    
    static func generatePdfThumbnail(pdfDocument: PDFDocument,
                                     size: CGSize?,
                                     forPageIndex pageIndex: Int = 0) -> UIImage? {
        guard pageIndex >= 0, pageIndex < pdfDocument.pageCount else { return nil }
        guard let pdfDocumentPage = pdfDocument.page(at: pageIndex) else { return nil }
        if let size = size {
            let nativeScale = UIScreen.main.nativeScale
            let nativeSize = CGSize(width: size.width * nativeScale, height: size.height * nativeScale)
            return pdfDocumentPage.thumbnail(of: nativeSize, for: PDFDisplayBox.trimBox)
        } else {
            // A page rotated by a quarter turn (90°/270°) renders with its width and
            // height swapped; size the target box to the rotation-adjusted bounds so the
            // thumbnail keeps the correct aspect instead of being squeezed into the
            // unrotated media box.
            let mediaBoxSize = pdfDocumentPage.bounds(for: .mediaBox).size
            let targetSize = (pdfDocumentPage.rotation % 180 != 0)
                ? CGSize(width: mediaBoxSize.height, height: mediaBoxSize.width)
                : mediaBoxSize
            return pdfDocumentPage.thumbnail(of: targetSize, for: .mediaBox)
        }
    }
    
    static func applyPostProcess(toPdfDocument pdfDocument: PDFDocument, margins: MarginsOption, compression: CompressionOption) -> PDFDocument {

        let horizontalMargin = margins.horizontalMargin
        let quality = compression.quality

        // If neither margins nor compression are requested, return the document untouched.
        // Rasterizing every page is lossy (it discards selectable/vector text) and pointless here.
        guard horizontalMargin > 0 || quality < 1.0 else {
            return pdfDocument.dataRepresentation().flatMap { PDFDocument(data: $0) } ?? pdfDocument
        }

        guard pdfDocument.pageCount > 0 else {
            return pdfDocument.dataRepresentation().flatMap { PDFDocument(data: $0) } ?? pdfDocument
        }

        let newPdfDocument = PDFDocument()
        let applyCompression = quality < 1.0
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }

            // Fetch the page rect for the page we want to render.
            let pageRect = page.bounds(for: .mediaBox)
            // A page rotated by a quarter turn (90°/270°) displays with its width and
            // height swapped. `page.draw`/`PDFPage(image:)` honor that rotation, so the
            // output page must be sized to the rotation-adjusted bounds — otherwise a
            // rotated page shared with margins/compression comes out distorted.
            let originalSize = (page.rotation % 180 != 0)
                ? CGSize(width: pageRect.size.height, height: pageRect.size.width)
                : pageRect.size

            let newWidth = originalSize.width - horizontalMargin * 2
            let newHeight = (originalSize.height / originalSize.width) * newWidth

            // Draws the page inset by the margins and vertically centered. Identical math for a
            // bitmap or a PDF context; only the destination (raster vs vector) differs below.
            let drawPage: (CGContext) -> Void = { cg in
                // Fill the background (the margin area) with the margins color.
                cg.setFillColor(K.Misc.PdfMarginsColor.cgColor)
                cg.fill(CGRect(origin: .zero, size: originalSize))
                // Inset by the horizontal margin and center vertically.
                cg.translateBy(x: -pageRect.origin.x + horizontalMargin,
                               y: originalSize.height - pageRect.origin.y - (originalSize.height - newHeight) / 2)
                // Flip vertically because Core Graphics' origin is at the bottom.
                cg.scaleBy(x: newWidth / originalSize.width, y: -newHeight / originalSize.height)
                page.draw(with: .mediaBox, to: cg)
            }

            // Compress a page when compression is requested AND the page is effectively an
            // image: either it has no extractable text (a scan), or it is dominated by a
            // high-resolution image (e.g. a photo with a caption). A pure text page stays vector
            // so the text remains selectable — re-encoding it as JPEG would wreck quality for
            // little size gain. Apple's APIs can't recompress a single embedded image while
            // keeping the rest of the page vector, so an image-heavy page is flattened whole.
            let pageHasText = !(page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if applyCompression && (!pageHasText || Self.pageIsImageHeavy(page)) {
                // Image-only page: rasterize and re-encode as JPEG to actually shrink it.
                let renderer = UIGraphicsImageRenderer(size: originalSize)
                var newImage = renderer.image { ctx in drawPage(ctx.cgContext) }
                if let jpegData = newImage.jpegData(compressionQuality: quality),
                   let compressed = UIImage(data: jpegData) {
                    newImage = compressed
                }
                if let pdfPage = PDFPage(image: newImage) {
                    newPdfDocument.insert(pdfPage, at: newPdfDocument.pageCount)
                }
            } else {
                // Text/vector page (or margins-only): draw into a PDF context so the content
                // stays selectable and crisp instead of being flattened into an image.
                let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: originalSize))
                let pageData = pdfRenderer.pdfData { ctx in
                    ctx.beginPage()
                    drawPage(ctx.cgContext)
                }
                if let pageDocument = PDFDocument(data: pageData), let newPage = pageDocument.page(at: 0) {
                    newPdfDocument.insert(newPage, at: newPdfDocument.pageCount)
                }
            }
        }
        return newPdfDocument
    }

    /// Returns true when a page is dominated by a high-resolution embedded image
    /// (e.g. a photo with a caption), by inspecting the CGPDF XObject dictionary.
    static func pageIsImageHeavy(_ page: PDFPage, pixelThreshold: Int = 1_000_000) -> Bool {
        guard let cgPage = page.pageRef,
              let pageDict = cgPage.dictionary else { return false }

        var resources: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageDict, "Resources", &resources),
              let resources = resources else { return false }

        var xObjects: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &xObjects),
              let xObjects = xObjects else { return false }

        var maxPixels = 0
        CGPDFDictionaryApplyBlock(xObjects, { _, object, _ in
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(object, .stream, &stream),
                  let stream = stream,
                  let streamDict = CGPDFStreamGetDictionary(stream) else { return true }

            var subtype: UnsafePointer<CChar>?
            guard CGPDFDictionaryGetName(streamDict, "Subtype", &subtype),
                  let subtype = subtype, String(cString: subtype) == "Image" else { return true }

            var width: CGPDFInteger = 0
            var height: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(streamDict, "Width", &width)
            CGPDFDictionaryGetInteger(streamDict, "Height", &height)
            maxPixels = max(maxPixels, Int(width) * Int(height))
            return true
        }, nil)

        return maxPixels >= pixelThreshold
    }

    /// Fraction (0…1) of "inked" pixels on a low-resolution render of the page.
    ///
    /// Used to tell a genuinely empty page from one that carries only graphics — text
    /// extraction alone would call every image-only page blank. The render is tiny
    /// (100pt on the long side by default) so this stays cheap enough to run per page.
    static func pageInkRatio(_ page: PDFPage,
                             sampleLongSide: CGFloat = 100,
                             inkLevel: UInt8 = 250) -> CGFloat {
        let mediaBoxSize = page.bounds(for: .mediaBox).size
        // `thumbnail(of:for:)` applies /Rotate, so size the target box accordingly.
        let pageSize = (page.rotation % 180 != 0)
            ? CGSize(width: mediaBoxSize.height, height: mediaBoxSize.width)
            : mediaBoxSize
        guard pageSize.width > 0, pageSize.height > 0 else { return 0 }

        let scale = sampleLongSide / max(pageSize.width, pageSize.height)
        let width = max(1, Int((pageSize.width * scale).rounded()))
        let height = max(1, Int((pageSize.height * scale).rounded()))

        let thumbnail = page.thumbnail(of: CGSize(width: width, height: height), for: .mediaBox)
        guard let cgImage = thumbnail.cgImage else { return 0 }

        var pixels = [UInt8](repeating: 255, count: width * height)
        guard let context = CGContext(data: &pixels,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return 0 }
        // Pre-fill white: a transparent thumbnail must read as an empty page, not a black one.
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let inkedCount = pixels.reduce(0) { $1 < inkLevel ? $0 + 1 : $0 }
        return CGFloat(inkedCount) / CGFloat(width * height)
    }

    /// Below this fraction of inked pixels a page counts as blank (0.1%: tolerates
    /// scanner speckle and stray artifacts without swallowing a real line of text).
    static let blankPageInkThreshold: CGFloat = 0.001

    /// A page is blank when it carries no extractable text *and* renders essentially white.
    static func pageIsBlank(_ page: PDFPage, inkThreshold: CGFloat = PDFUtility.blankPageInkThreshold) -> Bool {
        if let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return false
        }
        return self.pageInkRatio(page) < inkThreshold
    }

    static func getSharePdfUrl(pdf: Pdf) -> URL {
        let documentDirectory = FileManager.default.temporaryDirectory
        return documentDirectory.appendingPathComponent(pdf.filename).appendingPathExtension(for: .pdf)
    }
    
    static func processToShare(pdf: Pdf, applyPostProcess: Bool) -> URL {
        
        var pdfDocument = pdf.pdfDocument
        if applyPostProcess {
            pdfDocument = Self.applyPostProcess(toPdfDocument: pdfDocument,
                                                margins: pdf.margins,
                                                compression: pdf.compression)
        }
        
        let fileURL = Self.getSharePdfUrl(pdf: pdf)
        
        let options: [PDFDocumentWriteOption: Any] = {
            if let password = pdf.password {
                return [
                    PDFDocumentWriteOption.userPasswordOption : password,
                    PDFDocumentWriteOption.ownerPasswordOption : password
                ]
            } else {
                return [:]
            }
        }()
        
        // Write with password protection
        pdfDocument.write(to: fileURL, withOptions: options)
        
        return fileURL
    }
    
    static func cleanSharedPdf(pdf: Pdf) {
        let fileUrl = Self.getSharePdfUrl(pdf: pdf)
        do {
            try FileManager.default.removeItem(at: fileUrl)
        } catch {
            print("PdfUtility - Failed to delete temporary file at '\(fileUrl)'. Error: \(error)")
        }
    }
    
    static func unlock(data: Data, password: String) -> CGPDFDocument? {
        guard let dataProvider = CGDataProvider(data: data as CFData) else { return nil }
        if let pdf = CGPDFDocument(dataProvider) {
            guard pdf.isEncrypted == true else { return pdf }
            guard pdf.unlockWithPassword("") == false else { return pdf }
            
            if let cPasswordString = password.cString(using: String.Encoding.utf8) {
                if pdf.unlockWithPassword(cPasswordString) {
                    return pdf
                }
            }
        }
        return nil
    }
    
    static func removePassword(data: Data, existingPDFPassword: String) throws -> Data? {
        
        guard let pdf = unlock(data: data, password: existingPDFPassword) else { return nil }

        let pageCount = pdf.numberOfPages
        guard pageCount > 0 else { return nil }

        let outputData = NSMutableData()
        autoreleasepool {
            UIGraphicsBeginPDFContextToData(outputData, .zero, nil)

            for index in 1...pageCount {
                guard let page = pdf.page(at: index) else { continue }
                let pageRect = page.getBoxRect(CGPDFBox.mediaBox)

                UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
                guard let ctx = UIGraphicsGetCurrentContext() else { continue }
                ctx.interpolationQuality = .high
                // Draw existing page
                ctx.saveGState()
                ctx.scaleBy(x: 1, y: -1)
                ctx.translateBy(x: 0, y: -pageRect.size.height)
                ctx.drawPDFPage(page)
                ctx.restoreGState()
            }

            UIGraphicsEndPDFContext()
        }
        return outputData as Data
    }
    
    static func decryptFile(pdf: Pdf, password: String = "") -> AsyncOperation<Pdf, PdfError> {
        guard pdf.pdfDocument.isEncrypted else {
            return AsyncOperation(status: .data(pdf))
        }
        
        guard pdf.pdfDocument.unlock(withPassword: password) else {
            return AsyncOperation(status: .error(.wrongPassword))
        }
        
        guard let pdfEncryptedData = pdf.pdfDocument.dataRepresentation() else {
            assertionFailure("Missing expected encrypted data")
            return AsyncOperation(status: .error(.unknownError))
        }
        
        guard let pdfDecryptedData = try? PDFUtility.removePassword(data: pdfEncryptedData, existingPDFPassword: password) else {
            assertionFailure("Missing expected decrypted data")
            return AsyncOperation(status: .error(.unknownError))
        }
        
        guard let pdfDecryptedDocument = PDFDocument(data: pdfDecryptedData) else {
            assertionFailure("Cannot decode pdf from decrypted data")
            return AsyncOperation(status: .error(.unknownError))
        }
        var pdf = pdf
        pdf.updateDocument(pdfDecryptedDocument)
        pdf.updatePassword(password)
        return AsyncOperation(status: .data(pdf))
    }
    
    static func hasPdfWidget(pdf: Pdf) -> Bool {
        for pageIndex in 0..<pdf.pdfDocument.pageCount {
            if let page = pdf.pdfDocument.page(at: pageIndex) {
                if page.annotations.contains(where: { $0.isWidgetAnnotation }) {
                    return true
                }
            }
        }
        return false
    }

    /// Concatenates the extractable text of every page (newline-separated). Empty
    /// for image-only documents that haven't been OCR'd. Used to index PDFs for the
    /// archive's full-text search.
    static func extractText(from pdfDocument: PDFDocument) -> String {
        var text = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let pageText = pdfDocument.page(at: pageIndex)?.string,
                  !pageText.isEmpty else { continue }
            if !text.isEmpty { text += "\n" }
            text += pageText
        }
        return text
    }
}

extension UIImage {
    
    func pdfPage() -> PDFPage? {
        guard let fixedOrientationImage = self.fixedOrientation() else {
            return nil
        }
        // Typical Letter PDF page size and margins
        let pageBounds = CGRect(origin: .zero, size: K.Misc.PdfPageSize)
        let margin: CGFloat = K.Misc.PdfPageDefaultMargin

        let imageMaxWidth = pageBounds.width - (margin * 2)
        let imageMaxHeight = pageBounds.height - (margin * 2)

        let image = fixedOrientationImage.scaledImage(scaleFactor: size.scaleFactor(forMaxWidth: imageMaxWidth,
                                                                                    maxHeight: imageMaxHeight)) ?? fixedOrientationImage
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        
        // This procedure for rendering pdf pages (copied from WeScan) is the only one that seems
        // to make the applyPostProcess method to work. Creating PDFPage instances with PDFPage.init(_ image: UIImage)
        // causes the PDFPage.draw method to draw a black page.
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            
            ctx.cgContext.interpolationQuality = .high
            
            image.draw(at: CGPoint(x: (pageBounds.width - image.size.width) / 2,
                                   y: (pageBounds.height - image.size.height) / 2))
        }
        return PDFDocument(data: data)?.page(at: 0)
    }
    
    /// Scales the image to the specified size in the RGB color space.
    ///
    /// - Parameters:
    ///   - scaleFactor: Factor by which the image should be scaled.
    /// - Returns: The scaled image.
    func scaledImage(scaleFactor: CGFloat) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let customColorSpace = CGColorSpaceCreateDeviceRGB()

        let width = CGFloat(cgImage.width) * scaleFactor
        let height = CGFloat(cgImage.height) * scaleFactor
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let bitmapInfo = cgImage.bitmapInfo.rawValue

        guard let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: customColorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))

        return context.makeImage().flatMap { UIImage(cgImage: $0) }
    }
    
    /// Fix image orientaton to protrait up
    func fixedOrientation() -> UIImage? {
        guard imageOrientation != UIImage.Orientation.up else {
            // This is default orientation, don't need to do anything
            return self.copy() as? UIImage
        }
        
        guard let cgImage = self.cgImage else {
            // CGImage is not available
            return nil
        }
        
        guard let colorSpace = cgImage.colorSpace, let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil // Not able to create CGContext
        }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
        case .up, .upMirrored:
            break
        @unknown default:
            fatalError("Missing...")
            break
        }
        
        // Flip image one more time if needed to, this is to prevent flipped image
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        @unknown default:
            fatalError("Missing...")
            break
        }
        
        ctx.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        
        guard let newCGImage = ctx.makeImage() else { return nil }
        return UIImage.init(cgImage: newCGImage, scale: 1, orientation: .up)
    }
}

extension CGSize {
    /// Calculates an appropriate scale factor which makes the size fit inside both the `maxWidth` and `maxHeight`.
    /// - Parameters:
    ///   - maxWidth: The maximum width that the size should have after applying the scale factor.
    ///   - maxHeight: The maximum height that the size should have after applying the scale factor.
    /// - Returns: A scale factor that makes the size fit within the `maxWidth` and `maxHeight`.
    func scaleFactor(forMaxWidth maxWidth: CGFloat, maxHeight: CGFloat) -> CGFloat {
        if width < maxWidth && height < maxHeight { return 1 }

        let widthScaleFactor = 1 / (width / maxWidth)
        let heightScaleFactor = 1 / (height / maxHeight)

        // Use the smaller scale factor to ensure both the width and height are below the max
        return min(widthScaleFactor, heightScaleFactor)
    }
}

extension PDFView {
    var currentPageIndex: Int? {
        guard let document = self.document, let currentPage = self.currentPage else {
            return nil
        }
        for pageIndex in 0..<document.pageCount {
            if document.page(at: pageIndex) == currentPage {
                return pageIndex
            }
        }
        return nil
    }
}
