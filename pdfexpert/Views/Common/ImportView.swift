//
//  ImportView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/03/23.
//

import SwiftUI

struct ImportItem {
    let title: String
    let imageName: String
    let callBack: () -> ()
}

struct ImportView: View {
    
    let items: [ImportItem]
    
    var body: some View {
        VStack {
            Text("Import from")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(FontPalette.fontMedium(withSize: 20))
                .foregroundColor(ColorPalette.primaryText)
            Spacer(minLength: 20)
            ForEach(self.items, id: \.title) { item in
                ImportItemView(title: item.title, imageName: item.imageName, onPressed: item.callBack)
                Spacer().frame(height: 10)
            }
        }
        .padding(EdgeInsets(top: 44, leading: 16, bottom: 32, trailing: 16))
        .background(ColorPalette.secondaryBG)
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }
}

struct ImportView_Previews: PreviewProvider {
    
    static let items = [
        ImportItem(title: "File", imageName: "file", callBack: {}),
        ImportItem(title: "Gallery", imageName: "gallery", callBack: {}),
        ImportItem(title: "Camera", imageName: "camera", callBack: {}),
    ]
    
    static var previews: some View {
        ImportView(items: items)
    }
}
