//
//  Deeplink.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/08/23.
//

import Foundation

enum Deeplink {
    case chatPdf
    
    init?(fromCustomUrl url: URL) {
        guard url.absoluteString.starts(with: SharedStorage.schema) else {
            return nil
        }
        
        switch url.absoluteString {
        case "\(SharedStorage.schema)chatpdf":
            self = .chatPdf
        default:
            return nil
        }
    }
}
