//
//  PdfDocument+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 24/08/23.
//

import Foundation
import PDFKit

extension PDFDocument: Collection {
    
    public typealias Index = Int
    public typealias Element = PDFPage
    
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return self.pageCount }
    
    public subscript(index: Index) -> Element {
        get { return self.page(at: index)! }
    }
    
    public func index(after i: Index) -> Index {
        return i + 1
    }
}
