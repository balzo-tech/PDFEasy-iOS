//
//  ChatPdfViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import Foundation
import Factory

extension Container {
    var chatPdfViewModel: Factory<ChatPdfViewModel> {
        self { ChatPdfViewModel() }
    }
}

class ChatPdfViewModel: ObservableObject {
    
    @Injected(\.analyticsManager) private var analyticsManager
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.chatPdf))
    }
}
