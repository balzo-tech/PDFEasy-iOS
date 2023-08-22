//
//  PdfPageSelectionView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/08/23.
//

import SwiftUI
import Factory

struct PdfPageSelectionView: View {
    
    @Binding var pageIndex: Int
    
    let title: String
    let pageThumbnails: [UIImage?]
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(self.pageThumbnails.enumerated()), id:\.offset) { index, pageThumbnail in
                            Button(action: {
                                self.pageIndex = index
                                self.dismiss()
                            }) {
                                HStack {
                                    Text("\(index)")
                                        .foregroundColor(ColorPalette.primaryText)
                                        .font(FontPalette.fontRegular(withSize: 14))
                                        .minimumScaleFactor(0.5)
                                        .frame(width: 40, alignment: .leading)
                                    self.getPdfPageThumbnail(fromImage: pageThumbnail)
                                        .frame(width: 86)
                                        .padding([.top, .bottom], 8)
                                    Spacer()
                                }
                                .padding([.trailing, .leading], 16)
                            }
                            .frame(height: 94)
                            .background(self.getPageBackgroundColor(forPageIndex: index))
                            .id(index)
                        }
                    }
                    .onAppear{
                        if self.isScrollToAvailable {
                            reader.scrollTo(self.pageIndex, anchor: .center)
                        }
                    }
                }
                .padding([.top, .bottom], 16)
                .background(ColorPalette.primaryBG)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(self.title)
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.dismiss()
            })
        }
        .background(ColorPalette.primaryBG)
        .onAppear {
            self.analyticsManager.track(event: .reportScreen(.pageSelection))
        }
    }
    
    func getPageBackgroundColor(forPageIndex pageIndex: Int) -> Color {
        if self.pageIndex == pageIndex {
            return ColorPalette.secondaryBG
        } else {
            return .clear
        }
    }
    
    @ViewBuilder private func getPdfPageThumbnail(fromImage image: UIImage?) -> some View {
        if let thumbnail = image {
            Color.clear
                .overlay(Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill())
                .clipShape(RoundedRectangle(cornerRadius: 10,
                            style: .continuous))
        } else {
            ColorPalette.secondaryBG
                .cornerRadius(10)
        }
    }
}

struct PdfPageSelectionView_Previews: PreviewProvider {
    
    static var previews: some View {
        if let pdf = K.Test.DebugPdf {
            let thumbnails = PDFUtility.generatePdfThumbnails(pdfDocument: pdf.pdfDocument,
                                                              size: K.Misc.ThumbnailSize)
            PdfPageSelectionView(pageIndex: .constant(0),
                                 title: pdf.filename,
                                 pageThumbnails: thumbnails)
        }
    }
}
