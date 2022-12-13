//
//  UIView+Shadow.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit

public extension UIView {func addShadow(shadowColor: UIColor, shadowOffset: CGSize, shadowOpacity: Float, shadowRadius: CGFloat) {
        self.layer.shadowColor = shadowColor.cgColor
        self.layer.shadowOffset = shadowOffset
        self.layer.shadowOpacity = shadowOpacity
        self.layer.shadowRadius = shadowRadius
        self.layer.masksToBounds = false
    }
    
    func clearShadow() {
        self.layer.shadowColor = nil
        self.layer.shadowOffset = CGSize.zero
        self.layer.shadowOpacity = 0
        self.layer.shadowRadius = 0
    }
}
