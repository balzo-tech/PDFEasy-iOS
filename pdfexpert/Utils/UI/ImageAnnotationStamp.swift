//
//  ImageAnnotationStamp.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 10/05/23.
//

import Foundation
import UIKit
import PDFKit

class ImageStampAnnotation: PDFAnnotation {
    var image: UIImage?
    
    init(with image: UIImage, forBounds bounds: CGRect, withProperties properties: [AnyHashable : Any]?) {
        super.init(bounds: bounds, forType: PDFAnnotationSubtype.stamp,  withProperties: properties)
        self.image = image
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext)   {
        guard let cgImage = self.image?.cgImage else { return }
        context.draw(cgImage, in: self.bounds)
    }
}
