//
//  ImportView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/03/23.
//

import SwiftUI

struct ImportView: View {
    
    let onFileImportPressed: () -> ()
    let onCameraImportPressed: () -> ()
    let onGalleryImportPressed: () -> ()
    
    var body: some View {
        VStack {
            Text("Import from")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(FontPalette.fontBold(withSize: 28))
                .foregroundColor(ColorPalette.thirdText)
            Spacer().frame(height: 80)
            ImportItemView(title: "File", imageName: "file", onPressed: { self.onFileImportPressed() })
            Spacer().frame(height: 20)
            ImportItemView(title: "Camera", imageName: "camera", onPressed: { self.onCameraImportPressed() })
            Spacer().frame(height: 20)
            ImportItemView(title: "Gallery", imageName: "gallery", onPressed: { self.onGalleryImportPressed() })
        }
        .padding(EdgeInsets(top: 44, leading: 32, bottom: 65, trailing: 32))
        .background(ColorPalette.secondaryBG)
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }
}

struct ImportView_Previews: PreviewProvider {
    static var previews: some View {
        ImportView(onFileImportPressed: {},
                   onCameraImportPressed: {},
                   onGalleryImportPressed: {})
    }
}
