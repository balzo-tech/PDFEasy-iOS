//
//  AnimationPalette.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/03/23.
//

import Foundation
import SwiftUI

enum AnimationType: String {
    case dots = "loading"
    case pdf = "pdf-scanning"
}

extension AnimationType {
    var view: some View {
        var view = LottieView(filename: self.rawValue)
        switch self {
        case .dots: view = view.loop()
        case .pdf: view = view.loop(autoReverse: true)
        }
        return GeometryReader { geometryReader in
            view.frame(width: geometryReader.size.width / 2.0)
                .frame(maxHeight: .infinity)
                .position(x: geometryReader.size.width / 2.0, y: geometryReader.size.height / 2.0)
        }
    }
}
