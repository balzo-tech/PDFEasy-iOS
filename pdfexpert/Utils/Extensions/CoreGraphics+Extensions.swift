//
//  CoreGraphics+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 07/09/23.
//

import Foundation

extension CGSize {
    var aspectRatio: CGFloat {
        return self.width / self.height
    }
    
    func clipToSize(
        _ clippingSize: CGSize,
        horizontalMargin: CGFloat = 0,
        verticalMargin: CGFloat = 0,
        keepAspectRatio: Bool = true
    ) -> CGSize {
        var clippedWidth: CGFloat = self.width
        var clippedHeight: CGFloat = self.height
        
        let maxHeight: CGFloat = clippingSize.height - horizontalMargin
        if clippedHeight > maxHeight {
            clippedHeight = maxHeight
            clippedWidth = clippedHeight * self.aspectRatio
        }
        
        let maxWidth: CGFloat = clippingSize.height - verticalMargin
        if clippedWidth > maxWidth {
            clippedWidth = maxWidth
            clippedHeight = clippedWidth / self.aspectRatio
        }
        
        return CGSize(width: clippedWidth, height: clippedHeight)
    }
}
