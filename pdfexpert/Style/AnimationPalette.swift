//
//  AnimationPalette.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/03/23.
//

import Foundation

enum AnimationType: String {
    case dots = "loading"
    case pdf = "pdf-scanning"
}

extension AnimationType {
    var view: LottieView {
        LottieView(filename: self.rawValue)
    }
}
