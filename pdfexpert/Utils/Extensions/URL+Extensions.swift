//
//  URL+Extensions.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 28/07/23.
//

import Foundation

extension URL {
    var filename: String {
        self.deletingPathExtension().lastPathComponent
    }
}
