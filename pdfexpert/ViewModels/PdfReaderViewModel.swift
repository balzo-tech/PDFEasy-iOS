//
//  PdfReaderViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import Foundation
import Factory
import SwiftUI
import PDFKit

extension Container {
    var pdfReaderViewModel: ParameterFactory<PdfReaderViewModel.Params, PdfReaderViewModel> {
        self { PdfReaderViewModel(params: $0) }
    }
}

class PdfReaderViewModel: ObservableObject {
    
    struct Params {
        let pdf: Pdf
    }
    
    @Published var pages: [AttributedString?] = []
    @Published var pageIndex: Int = 0 {
        didSet {
            if let page = self.pdfView.document?.page(at: self.pageIndex) {
                self.pdfView.go(to: page)
            }
        }
    }
    
    @Published var pdfView: PDFView = PDFView()
    
    @Published var textMode: Bool = false
    @Published var fontScale: CGFloat = K.Misc.PdfReaderDefaultFontScale
    
    @Published var pageThumbnails: AsyncItem<[UIImage?]> = .empty
    @Published var showPageSelection: Bool = false
    
    @Published var pageImages: AsyncItemFailable<[PdfImage], SharedUnderlyingError> = .empty
    @Published var showPageImages: Bool = false
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    let pdf: Pdf
    
    init(params: Params) {
        self.pdf = params.pdf
        // TODO: find a reversable way to disable annotations
        self.pdf.forEach{ $0.annotations.forEach { $0.isReadOnly = true } }
        self.updatePages()
        
        self.pdfView.document = self.pdf.pdfDocument
        self.pdfView.displayDirection = .horizontal
        
        NotificationCenter.default.addObserver(
              self,
              selector: #selector(self.handlePageChange(notification:)),
              name: Notification.Name.PDFViewPageChanged,
              object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.PDFViewPageChanged, object: nil)
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.reader))
    }
    
    func updatePages() {
        self.pages = self.pdf.map { $0.attributedString?.getPdfBodyText(fontScale: self.fontScale) }
    }
    
    @MainActor
    func presentPageSelection() {
        if self.pageThumbnails.hasData {
            self.showPageSelection = true
        } else {
            self.pageThumbnails = .loading(.undeterminedProgress)
            Task {
                let task = Task<[UIImage?], Never> {
                    return PDFUtility.generatePdfThumbnails(pdfDocument: self.pdf.pdfDocument,
                                                            size: K.Misc.ThumbnailSize)
                }
                self.pageThumbnails = .data(await task.value)
                self.showPageSelection = true
            }
        }
    }
    
    @MainActor
    func presentPageImages() {
        guard self.pageIndex < self.pdf.pageCount else {
            self.pageImages = .error(.unknownError)
            return
        }
        
        let page = self.pdf[self.pageIndex]
        
        self.pageImages = .loading(.undeterminedProgress)
        do {
            var images: [PdfImage] = []
            try extractImages(from: page) { image, name in
                let uiImage: UIImage? = {
                    switch image {
                    case .jpg(let data):
                        return UIImage(data: data)
                    case .raw(let cgImage):
                        return UIImage(cgImage: cgImage)
                    }
                }()
                if let uiImage {
                    images.append(PdfImage(image: uiImage, caption: name))
                }
            }
            self.pageImages = .data(images)
            self.showPageImages = true
        } catch {
            self.pageImages = .error(SharedUnderlyingError.convertError(fromError: error))
        }
    }
    
    func switchTextMode() {
        self.textMode = !self.textMode
    }
    
    @objc private func handlePageChange(notification: Notification) {
        guard let currentPageindex = self.pdfView.currentPageIndex, notification.object as? PDFView == self.pdfView else {
            assertionFailure("Missing expected page index")
            return
        }
        self.pageIndex = currentPageindex
    }
}

fileprivate extension NSAttributedString {
    
    func getPdfBodyText(fontScale: CGFloat) -> AttributedString? {
        
        let trimmedAttributedString = self.attributedStringByTrimmingCharacterSet(charSet: .whitespacesAndNewlines)
        
        guard trimmedAttributedString.length > 0 else {
            return nil
        }
        
        var attributedString = AttributedString(trimmedAttributedString)
        attributedString.foregroundColor = ColorPalette.primaryText
        for run in attributedString.runs {
            let fontSize: CGFloat? = run.uiKit.font?.fontDescriptor
                .fontAttributes[UIFontDescriptor.AttributeName.size] as? CGFloat
            let scaledFontSize = (fontSize ?? 16.0) * fontScale
            attributedString[run.range].font = FontPalette.fontMedium(withSize: scaledFontSize)
        }
        return attributedString
    }
}
