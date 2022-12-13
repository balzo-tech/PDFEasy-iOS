//
//  UIView+Constraints.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit
import PureLayout

public extension UIView {
    var heightConstraintValue: CGFloat? {
        get {
            return self.constraints.first(where: { $0.firstAttribute == .height })?.constant
        }
        set {
            if let heightContraint = self.constraints.first(where: { $0.firstAttribute == .height }) {
                if let height = newValue {
                    heightContraint.constant = height
                } else {
                    heightContraint.autoRemove()
                }
            } else {
                if let height = newValue {
                    self.autoSetDimension(.height, toSize: height)
                }
            }
        }
    }
    
    var widthConstraintValue: CGFloat? {
        get {
            return self.constraints.first(where: { $0.firstAttribute == .width })?.constant
        }
        set {
            if let widthContraint = self.constraints.first(where: { $0.firstAttribute == .width }) {
                if let width = newValue {
                    widthContraint.constant = width
                } else {
                    widthContraint.autoRemove()
                }
            } else {
                if let width = newValue {
                    self.autoSetDimension(.width, toSize: width)
                }
            }
        }
    }
    
    func autoPinEdge(to view: UIView, with insets: UIEdgeInsets? = nil) {
        self.autoPinEdge(.top, to: .top, of: view, withOffset: insets?.top ?? 0.0)
        self.autoPinEdge(.bottom, to: .bottom, of: view, withOffset: insets?.bottom ?? 0.0)
        self.autoPinEdge(.leading, to: .leading, of: view, withOffset: insets?.left ?? 0.0)
        self.autoPinEdge(.trailing, to: .trailing, of: view, withOffset: insets?.right ?? 0.0)
    }
}

