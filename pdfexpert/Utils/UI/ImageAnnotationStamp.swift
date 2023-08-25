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
    
    private let stampImage: UIImage?
    
    init(with image: UIImage, forBounds bounds: CGRect, withProperties properties: [AnyHashable : Any]?) {
        self.stampImage = image
        super.init(bounds: bounds, forType: PDFAnnotationSubtype.stamp,  withProperties: properties)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext)   {
        guard let cgImage = self.stampImage?.cgImage else { return }
        context.draw(cgImage, in: self.bounds)
    }
}
