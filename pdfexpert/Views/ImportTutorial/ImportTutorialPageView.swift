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
            Spacer()
            Text(self.title)
                .font(forCategory: .title2)
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 80, alignment: .top)
                .padding([.leading, .trailing], 32)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 20)
            Image(self.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 600)
            Spacer().frame(height: 40)
            Text(self.description)
                .font(forCategory: .body1)
                .foregroundColor(ColorPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 80, alignment: .top)
                .padding([.leading, .trailing], 32)
                .multilineTextAlignment(.center)
            Spacer()
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
                               description: "Select the \(K.Misc.AppTitle) app to import the PDF")
    }
}
