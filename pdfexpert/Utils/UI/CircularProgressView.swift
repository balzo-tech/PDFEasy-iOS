//
//  CircularProgressView.swift
//  StoryKidsAI
//
//  Created by Leonardo Passeri on 08/03/23.
//

import SwiftUI

struct CircularProgressView: View {
    
    let foregroundColor: Color
    let backgroundColor: Color
    let width: CGFloat
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    self.backgroundColor,
                    lineWidth: self.width
                )
            Circle()
                .trim(from: 0, to: self.progress)
                .stroke(
                    self.foregroundColor,
                    style: StrokeStyle(
                        lineWidth: self.width,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: self.progress)

        }
    }
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        CircularProgressView(foregroundColor: .black,
                             backgroundColor: .gray,
                             width: 20,
                             progress: 0.4)
        .previewLayout(PreviewLayout.fixed(width: 200, height: 200))
        .padding()
    }
}
