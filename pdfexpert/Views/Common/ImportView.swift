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
                .font(FontPalette.fontBold(withSize: 28))
                .foregroundColor(ColorPalette.thirdText)
            Spacer()
            ForEach(self.items, id: \.title) { item in
                ImportItemView(title: item.title, imageName: item.imageName, onPressed: item.callBack)
                Spacer().frame(height: 20)
            }
        }
        .padding(EdgeInsets(top: 44, leading: 32, bottom: 45, trailing: 32))
        .background(ColorPalette.secondaryBG)
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }
}

struct ImportView_Previews: PreviewProvider {
    
    static let items = [
        ImportItem(title: "File", imageName: "file", callBack: {}),
        ImportItem(title: "Camera", imageName: "camera", callBack: {}),
        ImportItem(title: "Gallery", imageName: "gallery", callBack: {})
    ]
    
    static var previews: some View {
        ImportView(items: items)
    }
}
