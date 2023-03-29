//
//  RoundedCorner.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/03/23.
//

import Foundation
import SwiftUI

struct RoundedCorner: Shape {

    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: self.corners,
                                cornerRadii: CGSize(width: self.radius,
                                                    height: self.radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        self.clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
