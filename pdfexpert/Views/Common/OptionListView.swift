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
        VStack(spacing: DS.Spacing.md) {
            Text(self.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(forCategory: .title3)
                .foregroundStyle(ColorPalette.textPrimary)
            if self.scrollable {
                ScrollView {
                    self.itemsView
                }
            } else {
                self.itemsView
            }
        }
        .padding(EdgeInsets(top: DS.Spacing.sm, leading: DS.Spacing.md,
                            bottom: DS.Spacing.xl, trailing: DS.Spacing.md))
        .background(ColorPalette.background)
        .cornerRadius(28, corners: [.topLeft, .topRight])
    }

    @ViewBuilder private var itemsView: some View {
        VStack(spacing: DS.Spacing.xs) {
            ForEach(self.items, id: \.title) { item in
                OptionItemView(title: item.title,
                               imageName: item.imageName,
                               isSystemImage: item.isSystemImage,
                               onPressed: item.callBack)
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
