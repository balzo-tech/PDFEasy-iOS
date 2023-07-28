//
//  OptionListView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/03/23.
//

import SwiftUI

struct OptionItem {
    let title: String
    let imageName: String
    let callBack: () -> ()
}

struct OptionListView: View {
    
    let title: String
    let items: [OptionItem]
    
    var body: some View {
        VStack {
            Text(self.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(FontPalette.fontMedium(withSize: 20))
                .foregroundColor(ColorPalette.primaryText)
            Spacer(minLength: 20)
            ForEach(self.items, id: \.title) { item in
                OptionItemView(title: item.title, imageName: item.imageName, onPressed: item.callBack)
                Spacer().frame(height: 10)
            }
        }
        .padding(EdgeInsets(top: 44, leading: 16, bottom: 32, trailing: 16))
        .background(ColorPalette.secondaryBG)
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }
}

struct OptionListView_Previews: PreviewProvider {
    
    static let items = [
        OptionItem(title: "File", imageName: "file", callBack: {}),
        OptionItem(title: "Gallery", imageName: "gallery", callBack: {}),
        OptionItem(title: "Camera", imageName: "camera", callBack: {}),
    ]
    
    static var previews: some View {
        OptionListView(title: "Import from", items: items)
    }
}
