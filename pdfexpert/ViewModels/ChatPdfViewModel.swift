//
//  ChatPdfViewModel.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import Foundation
import Factory
import Combine

extension Container {
    var chatPdfViewModel: ParameterFactory<ChatPdfViewModel.Parameters, ChatPdfViewModel> {
        self { ChatPdfViewModel(parameters: $0) }
    }
}

class ChatPdfViewModel: ObservableObject {
    
    struct Parameters {
        let chatPdfRef: ChatPdfRef
    }
    
    @Injected(\.chatPdfManager) private var chatPdfManager
    @Injected(\.analyticsManager) private var analyticsManager
    
    @Published var messages = [ChatPdfMessage]()
    
    private let chatPdfRef: ChatPdfRef
    
    private var cancelBag = Set<AnyCancellable>()
    
    init(parameters: Parameters) {
        self.chatPdfRef = parameters.chatPdfRef
    }
    
    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.chatPdf))
    }
    
    func onDisappear() {
        self.chatPdfManager.deletePdf(ref: self.chatPdfRef)
    }
    
    func getResponse(text: String) {
        
        self.analyticsManager.track(event: .chatPdfMessageSent)
        
        self.addMessage(ChatPdfMessage(role: .user, type: .text, content: text))
        self.addMessage(ChatPdfMessage(role: .assistant, type: .indicator, content: ""))
        
        self.chatPdfManager.generateText(ref: self.chatPdfRef, prompt: text)
            .sink(receiveCompletion: { [weak self] subscriptionCompletion in
                if let error = subscriptionCompletion.error {
                    self?.addMessage(ChatPdfMessage(role: .assistant, type: .text, content: error.localizedDescription))
                }
            }, receiveValue: { [weak self] message in
                self?.addMessage(message)
            }).store(in: &self.cancelBag)
    }
    
    private func addMessage(_ message: ChatPdfMessage) {
        // if messages list is empty just add new message
        guard let lastMessage = self.messages.last else {
            self.messages.append(message)
            return
        }
        // if last message is an indicator switch with new one
        if lastMessage.type == .indicator && lastMessage.role != .user {
            self.messages[self.messages.count - 1] = message
        } else {
            // otherwise, add new message to the end of the list
            self.messages.append(message)
        }
    }
}
