//
//  ImportTutorialView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 08/05/23.
//

import SwiftUI
import Factory
import PagerTabStripView

struct ImportTutorialItem {
    let title: String
    let imageName: String
    let description: String
}

struct ImportTutorialView: View {
    
    static let items: [ImportTutorialItem] = [
        ImportTutorialItem(title: "Convert PDF from\nyour app",
                           imageName: "import_tutorial_1",
                           description: "Open the application that contains the pdf you want to convert"),
        ImportTutorialItem(title: "Convert PDF from\nyour app",
                           imageName: "import_tutorial_2",
                           description: "Select the pdf and press the button \"Open in\" or menu"),
        ImportTutorialItem(title: "Convert PDF from\nyour app",
                           imageName: "import_tutorial_3",
                           description: "Select the PDF Easy app to import the PDF"),
    ]
    
    var pageCount: Int { Self.items.count }
    
    @State var pageIndex: Int = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PagerTabStripView(
                    swipeGestureEnabled: .constant(false),
                    selection: self.$pageIndex
                ) {
                    ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                        ImportTutorialPageView(title: item.title,
                                               imageName: item.imageName,
                                               description: item.description)
                        .pagerTabItem(tag: index) { }
                    }
                }
                .pagerTabStripViewStyle(.bar() { Color(.clear) })
                PageControl(currentPageIndex: self.pageIndex,
                            numberOfPages: self.pageCount,
                            currentPageColor: ColorPalette.buttonGradientStart,
                            normalPageColor: ColorPalette.buttonGradientStart.opacity(0.3))
                .frame(height: 40)
                Spacer()
                self.getDefaultButton(text: self.buttonText,
                                      onButtonPressed: self.onButtonPressed)
                .padding([.leading, .trailing], 16)
            }
            .padding(.top, 16)
            .padding(.bottom, 30)
            .background(ColorPalette.primaryBG)
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: { self.dismiss() })
            .onAppear() {
                Container.shared.analyticsManager().track(event: .reportScreen(.importTutorial))
            }
        }
    }
    
    private var buttonText: String {
        self.pageIndex + 1 < self.pageCount ? "Continue" : "Ok, I got it"
    }
    
    private func onButtonPressed() {
        if self.pageIndex + 1 < self.pageCount {
            self.pageIndex += 1
        } else {
            Container.shared.analyticsManager().track(event: .importTutorialCompleted)
            self.dismiss()
        }
    }
}

struct ImportTutorialView_Previews: PreviewProvider {
    static var previews: some View {
        ImportTutorialView()
    }
}
