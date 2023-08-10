//
//  ChatPdfInitParams.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/07/23.
//

import Foundation

struct ChatPdfInitParams: Hashable, Identifiable {
    
    var id: Self { return self }
    
    let chatPdfRef: ChatPdfRef
    let setupData: ChatPdfSetupData
}
