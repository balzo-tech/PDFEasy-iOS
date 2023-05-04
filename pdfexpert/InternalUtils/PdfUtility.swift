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
    
    static func generatePdfThumbnail(documentData: Data,
                                     size: CGSize,
                                     forPageIndex pageIndex: Int = 0) -> UIImage? {
        guard let pdfDocument = PDFDocument(data: documentData) else { return nil }
        return self.generatePdfThumbnail(pdfDocument: pdfDocument,
                                         size: size,
                                         forPageIndex: pageIndex)
    }
    
    static func generatePdfThumbnail(pdfDocument: PDFDocument,
                                     size: CGSize,
                                     forPageIndex pageIndex: Int = 0) -> UIImage? {
        guard pageIndex >= 0, pageIndex < pdfDocument.pageCount else { return nil }
        let pdfDocumentPage = pdfDocument.page(at: pageIndex)
        let nativeScale = UIScreen.main.nativeScale
        let nativeSize = CGSize(width: size.width * nativeScale, height: size.height * nativeScale)
        return pdfDocumentPage?.thumbnail(of: nativeSize, for: PDFDisplayBox.trimBox)
    }
    
    static func applyPostProcess(toPdfDocument pdfDocument: PDFDocument, horizontalMargin: CGFloat, quality: CGFloat) -> PDFDocument {
        
        guard pdfDocument.pageCount > 0 else { return PDFDocument(data: pdfDocument.dataRepresentation()!)! }
        
        let newPdfDocument = PDFDocument()
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            // Fetch the page rect for the page we want to render.
            let pageRect = page.bounds(for: .mediaBox)
            
            let originalSize = pageRect.size
            
            let newWidth = originalSize.width - horizontalMargin * 2
            let newHeight = (originalSize.height / originalSize.width) * newWidth
            
            let renderer = UIGraphicsImageRenderer(size: originalSize)
            var newImage = renderer.image { ctx in
                
                // Set and fill the background color.
                K.Misc.PdfMarginsColor.set()
                ctx.fill(pageRect)
                
                // Translate the context so that we only draw the `cropRect`.
                ctx.cgContext.translateBy(x: -pageRect.origin.x + horizontalMargin,
                                          y: originalSize.height - pageRect.origin.y - (originalSize.height - newHeight)/2)

                // Flip the context vertically because the Core Graphics coordinate system starts from the bottom.
                ctx.cgContext.scaleBy(x: newWidth / originalSize.width, y: -newHeight / originalSize.height)
                
                // Draw the PDF page.
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            if quality < 1.0, let jpegData = newImage.jpegData(compressionQuality: quality) {
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
}

fileprivate extension UIImage {
    
    func pdfPage() -> PDFPage? {
        // Typical Letter PDF page size and margins
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 40

        let imageMaxWidth = pageBounds.width - (margin * 2)
        let imageMaxHeight = pageBounds.height - (margin * 2)

        let image = scaledImage(scaleFactor: size.scaleFactor(forMaxWidth: imageMaxWidth, maxHeight: imageMaxHeight)) ?? self
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
