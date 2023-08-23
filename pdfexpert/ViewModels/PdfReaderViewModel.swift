//
//  PdfReaderViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import Foundation
import Factory
import SwiftUI

extension Container {
    var pdfReaderViewModel: ParameterFactory<PdfReaderViewModel.Params, PdfReaderViewModel> {
        self { PdfReaderViewModel(params: $0) }
    }
}

class PdfReaderViewModel: ObservableObject {
    
    struct Params {
        let pdf: Pdf
    }
    
    var pdfFileName: String { self.pdf.filename }
    var pdfPageCount: Int { self.pdf.pageCount }
    
    @Published var pages: [AttributedString?] = []
    @Published var pageIndex: Int = 0
    
    @Published var fontScale: CGFloat = K.Misc.PdfReaderDefaultFontScale
    
    @Published var pageThumbnails: AsyncItem<[UIImage?]> = .empty
    @Published var showPageSelection: Bool = false
    
    @Published var pageImages: AsyncItemFailable<[PdfImage], SharedUnderlyingError> = .empty
    @Published var showPageImages: Bool = false
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    private let pdf: Pdf
    
    init(params: Params) {
        self.pdf = params.pdf
        self.updatePages()
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