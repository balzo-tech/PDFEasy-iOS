//
//  UIStackView+Palette.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 14/12/22.
//

import UIKit
import Foundation

extension UIStackView {
    func addLabel(withText text: String,
                  fontStyle: FontStyle,
                  colorType: ColorType,
                  textAlignment: NSTextAlignment = .center,
                  underlined: Bool = false,
                  numberOfLines: Int = 0,
                  horizontalInset: CGFloat = 0) {
        let attributedString = NSAttributedString.create(withText: text,
                                                         fontStyle: fontStyle,
                                                         colorType: colorType,
                                                         textAlignment: textAlignment,
                                                         underlined: underlined)
        self.addLabel(attributedString: attributedString,
                      numberOfLines: numberOfLines,
                      horizontalInset: horizontalInset)
    }
    
    func addLabel(withText text: String,
                  fontStyle: FontStyle,
                  color: UIColor,
                  textAlignment: NSTextAlignment = .center,
                  underlined: Bool = false,
                  numberOfLines: Int = 0,
                  horizontalInset: CGFloat = 0) {
        let attributedString = NSAttributedString.create(withText: text,
                                                         fontStyle: fontStyle,
                                                         color: color,
                                                         textAlignment: textAlignment,
                                                         underlined: underlined)
        self.addLabel(attributedString: attributedString,
                      numberOfLines: numberOfLines,
                      horizontalInset: horizontalInset)
    }
    
    func addImage(withImage image: UIImage?,
                  color: UIColor,
                  sizeDimension: CGFloat,
                  horizontalInset: CGFloat = 0) {
        let imageView = UIImageView(image: image)
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.width, toSize: sizeDimension)
        self.addArrangedSubview(imageView, horizontalInset: horizontalInset)
    }
    
    func addImage(withImage image: UIImage?,
                  color: UIColor,
                  sizeDimension: CGFloat,
                  verticalDimension: CGFloat,
                  horizontalInset: CGFloat = 0) {
        let imageView = UIImageView(image: image)
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.width, toSize: sizeDimension)
        imageView.autoSetDimension(.height, toSize: verticalDimension)
        self.addArrangedSubview(imageView, horizontalInset: horizontalInset)
    }
    
}
