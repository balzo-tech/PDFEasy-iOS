//
//  MessageIndicatorView.swift
//  PdfExpert
//
//  The three dots shown while the assistant is reading the document.
//
//  Bare dots, with no pill of their own: the bubble around them is the one
//  `MessageView` draws for any assistant turn, so the answer appears to fill a
//  shape that was already there rather than replacing a differently-coloured
//  one.
//

import SwiftUI

struct MessageIndicatorView: View {
    var body: some View {
        HStack(spacing: 5) {
            DotView()
            DotView(delay: 0.2)
            DotView(delay: 0.4)
        }
        .foregroundColor(ColorPalette.textSecondary)
    }
}

struct DotView: View {

    @State var scale: CGFloat = 0.5
    @State var delay: Double = 0

    var body: some View {
        Circle()
            .frame(width: 7, height: 7)
            .scaleEffect(self.scale)
            .onAppear {
                withAnimation(Animation.easeInOut.repeatForever().delay(self.delay)) {
                    self.scale = 1
                }
            }
    }
}

struct MessageIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        MessageIndicatorView()
            .padding()
            .background(ColorPalette.surface)
    }
}
