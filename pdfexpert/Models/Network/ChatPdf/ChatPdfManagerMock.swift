//
//  ChatPdfManagerMock.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 02/03/23.
//

import Foundation
import Combine
import Moya

class ChatPdfManagerMock: ChatPdfManagerImpl {
    
    override func createProvider() -> MoyaProvider<ChatPdfService> {
        if K.Test.ChatPdf.NetworkStubsDelay > 0.0 {
            // Delayed responses (to test progress HUD, for example, or other UI tests)
            return MoyaProvider<ChatPdfService>(stubClosure: MoyaProvider.delayedStub(K.Test.ChatPdf.NetworkStubsDelay),
                                                plugins: [self.loggerPlugin])
        } else {
            // Immediate stubs for unit tests
            return MoyaProvider<ChatPdfService>(stubClosure: MoyaProvider.immediatelyStub,
                                                plugins: [self.loggerPlugin])
        }
    }
}
