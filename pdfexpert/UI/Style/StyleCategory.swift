//
//  StyleCategory.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 13/12/22.
//

import UIKit

protocol StyleCategory {
    associatedtype View
    var style: Style<View> { get }
}

