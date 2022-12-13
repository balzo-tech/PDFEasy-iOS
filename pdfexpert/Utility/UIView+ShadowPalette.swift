//
//  UIView+ShowPalette.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit

public extension UIView {
    func addShadowLinear(goingDown: Bool) {
        self.addShadow(shadowColor: ColorPalette.shadowColor,
                       shadowOffset: CGSize(width: 0.0, height: goingDown ? 4.0 : -4.0),
                       shadowOpacity: 1.0,
                       shadowRadius: 4.0)
    }
    
    func addShadowButton() {
        self.addShadow(shadowColor: ColorPalette.shadowColor,
                       shadowOffset: CGSize(width: 0.0, height: 4.0),
                       shadowOpacity: 1.0,
                       shadowRadius: 4.0)
    }
    
    func addShadowCell() {
        self.addShadow(shadowColor: ColorPalette.shadowColor,
                       shadowOffset: CGSize(width: 0.0, height: 4.0),
                       shadowOpacity: 1.0,
                       shadowRadius: 4.0)
    }
}
