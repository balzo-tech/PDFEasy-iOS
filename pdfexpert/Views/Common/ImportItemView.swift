//
//  ImportItemView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/03/23.
//

import SwiftUI

struct ImportItemView: View {
    
    let title: String
    let imageName: String
    let onPressed: () -> ()
    
    var body: some View {
        Button(action: { self.onPressed() }) {
            HStack(spacing: 20) {
                Image(self.imageName)
                Text(self.title)
                    .font(FontPalette.fontBold(withSize: 16))
                    .foregroundColor(ColorPalette.thirdText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 24)
            .padding(.trailing, 24)
        }
        .frame(height: 62)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ColorPalette.thirdText, lineWidth: 1))
    }
}

struct ImportItemView_Previews: PreviewProvider {
    static var previews: some View {
        ImportItemView(title: "File", imageName: "file", onPressed: {})
    }
}
