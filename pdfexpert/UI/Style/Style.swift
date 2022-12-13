//
//  Style.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit

public protocol View {}
extension UIView: View {}

public extension View {
    
    func apply(style: Style<Self>) {
        style.stylize(self)
    }
}

public class Style<T> {
    
    let stylize: ((T) -> Void)
    
    public init(stylize: @escaping (T) -> Void) {
        self.stylize = stylize
    }
}

