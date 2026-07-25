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
    var isSystemImage: Bool = false
    let onPressed: () -> ()

    var body: some View {
        Button(action: { self.onPressed() }) {
            HStack(spacing: DS.Spacing.sm) {
                self.icon
                    .frame(width: 22, height: 22)
                    .foregroundStyle(ColorPalette.accent)
                Text(self.title)
                    .font(forCategory: .body3)
                    .foregroundStyle(ColorPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorPalette.textTertiary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .buttonStyle(PressableTileButtonStyle(radius: DS.Radius.control))
    }

    // System symbols are tinted with the accent color; bundled asset icons keep
    // their original rendering.
    @ViewBuilder private var icon: some View {
        if self.isSystemImage {
            Image(systemName: self.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(self.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

struct OptionItemView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            OptionItemView(title: "File", imageName: "doc", isSystemImage: true, onPressed: {})
            OptionItemView(title: "Camera", imageName: "camera", isSystemImage: true, onPressed: {})
        }
        .padding()
        .background(ColorPalette.background)
    }
}
