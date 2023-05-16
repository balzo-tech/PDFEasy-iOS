//
//  ImportTutorialPageView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 08/05/23.
//

import SwiftUI

struct ImportTutorialPageView: View {
    
    let title: String
    let imageName: String
    let description: String
    
    var body: some View {
        VStack(spacing: 0) {
            Text(self.title)
                .font(FontPalette.fontBold(withSize: 22))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 80, alignment: .top)
                .padding([.leading, .trailing], 32)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 20)
            Image(self.imageName)
            Spacer().frame(height: 40)
            Text(self.description)
                .font(FontPalette.fontRegular(withSize: 16))
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 80, alignment: .top)
                .padding([.leading, .trailing], 32)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 40)
        }
    }
}

struct ImportTutorialPageView_Previews: PreviewProvider {
    
    static var previews: some View {
        ImportTutorialPageView(title: "Convert PDF from\nyour app",
                               imageName: "import_tutorial_1",
                               description: "Open the application that contains the pdf you want to convert")
        ImportTutorialPageView(title: "Convert PDF from\nyour app",
                               imageName: "import_tutorial_2",
                               description: "Select the pdf and press the button \"Open in\" or menu")
        ImportTutorialPageView(title: "Convert PDF from\nyour app",
                               imageName: "import_tutorial_3",
                               description: "Select the PDF Easy app to import the PDF")
    }
}
