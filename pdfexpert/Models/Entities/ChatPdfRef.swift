//
//  ChatPdfRef.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 20/07/23.
//

import Foundation

struct ChatPdfRef: Hashable, Identifiable {
    
    var id: Self { return self }
    
    let sourceId: String
}
