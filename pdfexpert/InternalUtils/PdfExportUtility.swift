//
//  PdfExportUtility.swift
//  PdfExpert
//
//  Created by Giuseppe Lapenta on 12/07/26.
//

import Foundation
import PDFKit
import UIKit

/// The set of formats a PDF can be exported to. Each maps to one of the
/// `PdfExportUtility` entry points below.
enum PdfExportFormat: CaseIterable {
    case imagesPng
    case imagesJpeg
    case text
    case embeddedImages

    /// How the format is offered. Here rather than in the view because it is
    /// offered from two places now — a sheet from the Tools tab, a pushed screen
    /// from the editor — and a format that reads differently in each is a format
    /// the user cannot be sure they picked.
    var title: String {
        switch self {
        case .imagesPng: return String(localized: "Images (PNG)")
        case .imagesJpeg: return String(localized: "Images (JPEG)")
        case .text: return String(localized: "Text file")
        case .embeddedImages: return String(localized: "Embedded images")
        }
    }

    var systemImage: String {
        switch self {
        case .imagesPng: return "photo"
        case .imagesJpeg: return "photo.fill"
        case .text: return "doc.plaintext"
        case .embeddedImages: return "photo.on.rectangle"
        }
    }
}

/// Renders a PDF into shareable files written to the temporary directory. The
/// caller is responsible for cleaning them up once the share sheet is dismissed
/// (see `cleanupExportFiles`).
class PdfExportUtility {

    /// Renders every page to a full-size, rotation-aware image and writes it as PNG
    /// or JPEG. One file per page, named `<filename>-page-<n>.<ext>` (n is 1-based).
    static func exportPageImages(pdf: Pdf, asPng: Bool, jpegQuality: CGFloat = 0.8) throws -> [URL] {
        let document = pdf.pdfDocument
        let baseName = Self.sanitizedFilename(pdf.filename)
        let fileExtension = asPng ? "png" : "jpg"

        var urls: [URL] = []
        for pageIndex in 0..<document.pageCount {
            // size: nil renders the page at its full, rotation-adjusted media-box size.
            guard let image = PDFUtility.generatePdfThumbnail(pdfDocument: document,
                                                              size: nil,
                                                              forPageIndex: pageIndex) else {
                throw PdfExportError.unknownError
            }
            let imageData = asPng ? image.pngData() : image.jpegData(compressionQuality: jpegQuality)
            guard let imageData else {
                throw PdfExportError.unknownError
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(baseName)-page-\(pageIndex + 1)")
                .appendingPathExtension(fileExtension)
            try imageData.write(to: url)
            urls.append(url)
        }
        return urls
    }

    /// Extracts the document's selectable text into a single UTF-8 `.txt` file.
    /// Throws `.noTextFound` for image-only documents (which need OCR first).
    static func exportText(pdf: Pdf) throws -> URL {
        let text = PDFUtility.extractText(from: pdf.pdfDocument)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PdfExportError.noTextFound
        }
        let baseName = Self.sanitizedFilename(pdf.filename)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension("txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Writes every image embedded in the PDF to its own file. JPEG-encoded images
    /// are written verbatim (`.jpg`); every other variant is re-encoded as PNG.
    /// Files are named `<filename>-image-<n>.<ext>`. Throws `.noImagesFound` when
    /// the document embeds no images.
    static func exportEmbeddedImages(pdf: Pdf) throws -> [URL] {
        let baseName = Self.sanitizedFilename(pdf.filename)

        var urls: [URL] = []
        var imageIndex = 0
        // extractImages(from:extractor:) is a global helper from PDFImageExtractor.swift.
        // It invokes the closure synchronously for each embedded image, emitting an
        // `EmbeddedImage` (either a raw JPEG `Data` blob or a decoded `CGImage`).
        try extractImages(from: pdf.pdfDocument) { embeddedImage, _, _ in
            imageIndex += 1
            let fileData: Data?
            let fileExtension: String
            switch embeddedImage {
            case .jpg(let data):
                fileData = data
                fileExtension = "jpg"
            case .raw(let cgImage):
                fileData = UIImage(cgImage: cgImage).pngData()
                fileExtension = "png"
            }
            guard let fileData else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(baseName)-image-\(imageIndex)")
                .appendingPathExtension(fileExtension)
            do {
                try fileData.write(to: url)
                urls.append(url)
            } catch {
                // Skip a single image we couldn't persist rather than failing the
                // whole export.
                debugPrint("PdfExportUtility - Failed to write embedded image at '\(url)'. Error: \(error)")
            }
        }
        guard !urls.isEmpty else {
            throw PdfExportError.noImagesFound
        }
        return urls
    }

    /// Deletes every exported file, ignoring individual failures.
    static func cleanupExportFiles(_ urls: [URL]) {
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("PdfExportUtility - Failed to delete temporary file at '\(url)'. Error: \(error)")
            }
        }
    }

    /// Strips characters that are illegal (or awkward) in a filename so the exported
    /// files can be written to disk. Falls back to a generic name when nothing is left.
    private static func sanitizedFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.controlCharacters)
            .union(.newlines)
        let sanitized = filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? "export" : sanitized
    }
}
