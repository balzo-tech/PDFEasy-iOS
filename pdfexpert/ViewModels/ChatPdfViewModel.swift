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
        let chatPdfInitParams: ChatPdfInitParams
    }

    @Injected(\.chatPdfManager) private var chatPdfManager
    @Injected(\.analyticsManager) private var analyticsManager
    @Injected(\.chatUsageTracker) private var chatUsageTracker

    @Published var messages = [ChatPdfMessage]()
    /// Messages the user can still send this month. Drives the counter and the
    /// enabled/disabled state of the input bar.
    @Published var remainingMessages: Int = 0

    private let chatPdfRef: ChatPdfRef

    private var cancelBag = Set<AnyCancellable>()

    init(parameters: Parameters) {
        self.chatPdfRef = parameters.chatPdfInitParams.chatPdfRef
        self.messages.append(parameters.chatPdfInitParams.setupData.message)
        self.remainingMessages = self.chatUsageTracker.remainingMessages
    }

    func onAppear() {
        self.analyticsManager.track(event: .reportScreen(.chatPdf))
        self.remainingMessages = self.chatUsageTracker.remainingMessages
    }

    func onDisappear() {
        self.chatPdfManager.deletePdf(ref: self.chatPdfRef)
    }

    func getResponse(text: String) {

        // Enforce the monthly cap before doing any work.
        guard self.chatUsageTracker.remainingMessages > 0 else {
            self.analyticsManager.track(event: .chatMessageLimitReached)
            let limit = self.chatUsageTracker.monthlyLimit
            self.addMessage(ChatPdfMessage(role: .user, type: .text, content: text))
            self.addMessage(ChatPdfMessage(role: .assistant,
                                           type: .text,
                                           content: String(localized: "You've reached your monthly limit of \(limit) messages.")))
            self.remainingMessages = self.chatUsageTracker.remainingMessages
            return
        }

        self.analyticsManager.track(event: .chatPdfMessageSent)

        self.addMessage(ChatPdfMessage(role: .user, type: .text, content: text))
        self.addMessage(ChatPdfMessage(role: .assistant, type: .indicator, content: ""))

        // A message is being dispatched: consume one from the monthly allowance.
        self.chatUsageTracker.consumeMessage()
        self.remainingMessages = self.chatUsageTracker.remainingMessages

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

fileprivate extension ChatPdfSetupData {
    var message: ChatPdfMessage {
        ChatPdfMessage(role: .assistant, type: .text, content: self.summary, suggestedQuestions: self.suggestedQuestions)
    }
}
