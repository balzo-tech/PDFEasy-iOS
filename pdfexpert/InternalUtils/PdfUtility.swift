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
            return pdfDocumentPage.thumbnail(of: pdfDocumentPage.bounds(for: .mediaBox).size, for: .mediaBox)
        }
    }
    
    static func applyPostProcess(toPdfDocument pdfDocument: PDFDocument, margins: MarginsOption, compression: CompressionOption) -> PDFDocument {
        
        guard pdfDocument.pageCount > 0 else { return PDFDocument(data: pdfDocument.dataRepresentation()!)! }
        guard margins != .noMargins, compression != .noCompression else { return PDFDocument(data: pdfDocument.dataRepresentation()!)! }
        
        let newPdfDocument = PDFDocument()
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            // Fetch the page rect for the page we want to render.
            let pageRect = page.bounds(for: .mediaBox)
            
            let originalSize = pageRect.size
            
            let newWidth = originalSize.width - margins.horizontalMargin * 2
            let newHeight = (originalSize.height / originalSize.width) * newWidth
            
            let renderer = UIGraphicsImageRenderer(size: originalSize)
            var newImage = renderer.image { ctx in
                
                // Set and fill the background color.
                K.Misc.PdfMarginsColor.set()
                ctx.fill(pageRect)
                
                // Translate the context so that we only draw the `cropRect`.
                ctx.cgContext.translateBy(x: -pageRect.origin.x + margins.horizontalMargin,
                                          y: originalSize.height - pageRect.origin.y - (originalSize.height - newHeight)/2)

                // Flip the context vertically because the Core Graphics coordinate system starts from the bottom.
                ctx.cgContext.scaleBy(x: newWidth / originalSize.width, y: -newHeight / originalSize.height)
                
                // Draw the PDF page.
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            if compression.quality < 1.0, let jpegData = newImage.jpegData(compressionQuality: compression.quality) {
                let nsJpegData = NSData(data: jpegData)
                let unsafePointer = UnsafePointer<UInt8>(nsJpegData.bytes.bindMemory(to: UInt8.self, capacity: nsJpegData.length))
                if let dataPtr = CFDataCreate(kCFAllocatorDefault, unsafePointer, nsJpegData.length),
                   let dataProvider = CGDataProvider(data: dataPtr),
                   let cgImage = CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
                    newImage = UIImage(cgImage: cgImage)
                }
            }
            
            if let pdfPage = PDFPage(image: newImage) {
                newPdfDocument.insert(pdfPage, at: newPdfDocument.pageCount)
            }
        }
        return newPdfDocument
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
        if let pdf = CGPDFDocument(CGDataProvider(data: data as CFData)!) {
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
        
        if let pdf = unlock(data: data, password: existingPDFPassword) {
            let data = NSMutableData()
            
            autoreleasepool {
                let pageCount = pdf.numberOfPages
                UIGraphicsBeginPDFContextToData(data, .zero, nil)
                
                for index in 1...pageCount {
                    
                    let page = pdf.page(at: index)
                    let pageRect = page?.getBoxRect(CGPDFBox.mediaBox)
                    
                    
                    UIGraphicsBeginPDFPageWithInfo(pageRect!, nil)
                    let ctx = UIGraphicsGetCurrentContext()
                    ctx?.interpolationQuality = .high
                    // Draw existing page
                    ctx!.saveGState()
                    ctx!.scaleBy(x: 1, y: -1)
                    ctx!.translateBy(x: 0, y: -(pageRect?.size.height)!)
                    ctx!.drawPDFPage(page!)
                    ctx!.restoreGState()
                    
                }
                
                UIGraphicsEndPDFContext()
            }
            return data as Data
        }
        return nil
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
