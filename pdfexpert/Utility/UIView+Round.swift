//
//  UIView+Round.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import UIKit

public extension UIView {
    func round(radius: CGFloat) {
        var fAlpha: CGFloat = 0
        // Rememeber that self.backgroundColor must not clear and with Alpha == 1.0
        guard let backgroundColor = self.backgroundColor,
            backgroundColor.getRed(nil, green: nil, blue: nil, alpha: &fAlpha),
            fAlpha == 1 else {
            assertionFailure("Background color must have Alpha == 1")
            return
        }
        self.layer.cornerRadius = radius
        self.layer.masksToBounds = true
    }
    
    func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        // Note: to get correct mask frame size, call this in layoutSubviews() or viewDidLayoutSubviews()
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.frame = self.bounds
        mask.path = path.cgPath
        self.layer.mask = mask
    }
}
