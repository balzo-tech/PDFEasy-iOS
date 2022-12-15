//
//  GradientView+Extensions.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import UIKit

enum GradientViewType {
    case primaryBackground
    case primaryBackgroundHorizontal
    
    var colors: [UIColor] {
        switch self {
        case .primaryBackground:
            return [ColorPalette.color(withType: .primary), ColorPalette.color(withType: .gradientPrimaryEnd)]
        case .primaryBackgroundHorizontal:
            return [ColorPalette.color(withType: .primary), ColorPalette.color(withType: .gradientPrimaryEnd)]
        }
    }
    
    var locations: [Double] {
        switch self {
        case .primaryBackground: return [0.0, 1.0]
        case .primaryBackgroundHorizontal: return [0.0, 1.0]
        }
    }
    
    var startPoint: CGPoint {
        switch self {
        case .primaryBackground: return CGPoint(x: 0.0, y: 0.5)
        case .primaryBackgroundHorizontal: return CGPoint(x: 0.5, y: 0.0)
        }
    }
    
    var endPoint: CGPoint {
        switch self {
        case .primaryBackground: return CGPoint(x: 1.0, y: 0.5)
        case .primaryBackgroundHorizontal: return CGPoint(x: 0.5, y: 1.0)
        }
    }
}

extension GradientView {
    convenience init(type: GradientViewType) {
        self.init(colors: type.colors, locations: type.locations, startPoint: type.startPoint, endPoint: type.endPoint)
    }
}
