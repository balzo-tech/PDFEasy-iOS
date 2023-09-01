//
//  PdfImageViewerView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 23/08/23.
//

import SwiftUI
import Factory

struct PdfImage {
    let image: UIImage?
    let caption: String
}

struct PdfImageViewerView: View {
    
    let pageIndex: Int
    let images: [PdfImage]
    
    @State var imageIndex: Int = 0
    
    @Environment(\.dismiss) var dismiss
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if self.images.count > 0 {
                    TabView(selection: self.$imageIndex) {
                        ForEach(Array(self.images.enumerated()), id:\.offset) { _, image in
                            VStack(spacing: 16) {
                                if let uiImage = image.image {
                                    GeometryReader { proxy in
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: proxy.size.width, height: proxy.size.height)
                                            .clipShape(Rectangle())
                                            .modifier(ZoomImageModifier(contentSize: CGSize(width: proxy.size.width, height: proxy.size.height)))
                                    }
                                } else {
                                    Spacer()
                                    Text("Couldn't extract this image")
                                        .font(forCategory: .body1)
                                        .foregroundColor(ColorPalette.primaryText)
                                    Spacer()
                                }
                                Text(image.caption)
                                    .font(forCategory: .body1)
                                    .foregroundColor(ColorPalette.primaryText)
                                    .frame(height: 100)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .background(ColorPalette.primaryBG)
                    self.pageCounter(currentPageIndex: self.imageIndex,
                                     totalPages: self.images.count)
                } else {
                    Spacer()
                    Text("There are no images on this page")
                        .font(forCategory: .body1)
                        .foregroundColor(ColorPalette.primaryText)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
            .padding(16)
            .background(ColorPalette.primaryBG)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Page \(self.pageIndex + 1)")
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                self.dismiss()
            })
        }
        .background(ColorPalette.primaryBG)
        .onAppear {
            self.analyticsManager.track(event: .reportScreen(.pageSelection))
        }
    }
}

struct PdfImageViewerView_Previews: PreviewProvider {
    static var previews: some View {
        PdfImageViewerView(pageIndex: 0, images: [
            PdfImage(image: UIImage(named: "onboarding_chat_pdf"), caption: "onboarding chat pdf"),
            PdfImage(image: nil, caption: "onboarding chat pdf"),
            PdfImage(image: UIImage(named: "onboarding_convert"), caption: "onboarding convert"),
            PdfImage(image: UIImage(named: "onboarding_password"), caption: "onboarding password"),
            PdfImage(image: UIImage(named: "onboarding_signature"), caption: "onboarding signature"),
        ])
        .previewDisplayName("Standard")
        PdfImageViewerView(pageIndex: 0, images: [])
            .previewDisplayName("Empty")
    }
}
