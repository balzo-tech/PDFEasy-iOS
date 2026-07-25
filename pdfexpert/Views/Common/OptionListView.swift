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
    var isSystemImage: Bool = false
    let callBack: () -> ()
}

struct OptionListView: View {

    let title: String
    /// Opt-in scrolling for long lists (the editor's "…" menu). Off by default so the
    /// short lists keep their exact intrinsic-height layout.
    var scrollable: Bool = false
    let items: [OptionItem]

    var body: some View {
        VStack {
            Text(self.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(forCategory: .headline)
                .foregroundColor(ColorPalette.primaryText)
            Spacer(minLength: 20)
            if self.scrollable {
                ScrollView {
                    self.itemsView
                }
            } else {
                self.itemsView
            }
        }
        .padding(EdgeInsets(top: 44, leading: 16, bottom: 32, trailing: 16))
        .background(ColorPalette.secondaryBG)
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }

    @ViewBuilder private var itemsView: some View {
        VStack(spacing: 0) {
            ForEach(self.items, id: \.title) { item in
                OptionItemView(title: item.title, imageName: item.imageName, isSystemImage: item.isSystemImage, onPressed: item.callBack)
                Spacer().frame(height: 10)
            }
        }
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
