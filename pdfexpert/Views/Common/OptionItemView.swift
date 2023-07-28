//
//  OptionItemView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/03/23.
//

import SwiftUI

struct OptionItemView: View {
    
    let title: String
    let imageName: String
    let onPressed: () -> ()
    
    var body: some View {
        Button(action: { self.onPressed() }) {
            HStack(spacing: 16) {
                Image(self.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text(self.title)
                    .font(FontPalette.fontRegular(withSize: 18))
                    .foregroundColor(ColorPalette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorPalette.thirdText, lineWidth: 1))
    }
}

struct OptionItemView_Previews: PreviewProvider {
    static var previews: some View {
        OptionItemView(title: "File", imageName: "edit_option_password_unlock", onPressed: {})
    }
}
