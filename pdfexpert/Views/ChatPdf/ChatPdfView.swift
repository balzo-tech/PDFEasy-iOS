//
//  ChatPdfView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/07/23.
//

import SwiftUI
import Factory

struct ChatPdfView: View {

    @StateObject var viewModel: ChatPdfViewModel
    /// Supplied by the iPad split, where the conversation is a column rather
    /// than a modal and there is nothing to dismiss — closing means clearing the
    /// selection instead.
    var onClose: (() -> Void)? = nil

    @State var typingMessage: String = ""
    @Namespace var bottomID

    @Environment(\.dismiss) var dismiss

    private var canSendMessage: Bool {
        self.viewModel.remainingMessages > 0
    }

    /// A message of nothing but spaces is not a message, and it would still cost
    /// one of the twenty this month.
    private var trimmedMessage: String {
        self.typingMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSendNow: Bool {
        self.canSendMessage && !self.trimmedMessage.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !self.viewModel.messages.isEmpty {
                    self.conversation
                } else {
                    self.emptyState
                }
                self.composer
            }
            .background(ColorPalette.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Chat")
            .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                if let onClose = self.onClose {
                    onClose()
                } else {
                    self.dismiss()
                }
            })
            .onAppear() {
                self.viewModel.onAppear()
            }
            .onDisappear() {
                self.viewModel.onDisappear()
            }
        }
        .background(ColorPalette.background)
    }

    private var conversation: some View {
        ScrollViewReader { reader in
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(self.viewModel.messages.indices, id: \.self){ index in
                        let message = self.viewModel.messages[index]
                        MessageView(message: message,
                                    onSuggestedQuestionTapped: {
                            self.viewModel.getResponse(text: $0)
                        })
                    }
                    // Scroll anchor. Not a `Text("")`: an empty literal
                    // gets extracted into the string catalog as a blank
                    // key that no translator can do anything with.
                    Color.clear.frame(height: 0).id(self.bottomID)
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear{
                if self.isScrollToAvailable {
                    withAnimation{
                        reader.scrollTo(self.bottomID)
                    }
                }
            }
            .onChange(of: self.viewModel.messages.count){ _ in
                if self.isScrollToAvailable {
                    withAnimation{
                        reader.scrollTo(self.bottomID)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "ellipsis.bubble")
                .font(.system(size: 42, weight: .light))
                .foregroundColor(ColorPalette.textTertiary)
            Text("Write your first message!")
                .font(forCategory: .body2)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            // Turns red on its own once the allowance is gone: the field goes
            // quiet at the same moment, and this is the only thing on screen
            // that says why.
            Text(String(localized: "\(self.viewModel.remainingMessages) messages left this month"))
                .font(forCategory: .caption2)
                .foregroundColor(self.canSendMessage ? ColorPalette.textTertiary : ColorPalette.danger)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .bottom, spacing: 0) {
                TextField("Type your Message...", text: self.$typingMessage, axis: .vertical)
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.primaryText)
                    // A question typed to a document is prose, so it gets the
                    // capital letter and the corrections prose expects — this
                    // field used to turn both off.
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...5)
                    .padding(.leading, 16)
                    .padding(.vertical, 11)
                    .disabled(!self.canSendMessage)

                Button {
                    guard self.canSendNow else { return }
                    self.viewModel.getResponse(text: self.trimmedMessage)
                    self.typingMessage = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(self.canSendNow ? .white : ColorPalette.textTertiary)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(self.canSendNow ? ColorPalette.accent : ColorPalette.separator)
                        )
                }
                .disabled(!self.canSendNow)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ColorPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ColorPalette.separator, lineWidth: 1)
                    )
            )
            .opacity(self.canSendMessage ? 1.0 : 0.6)
            .onDisappear {
                UIApplication.dismissKeyboard()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(ColorPalette.background)
    }
}

struct ChatPdfView_Previews: PreviewProvider {

    private static let testRef = ChatPdfRef(sourceId: "test_source_id")
    private static let testSummary = "Welcome Message"
    private static let testSuggestedQuestions = [
        "How many pages this file has?",
        "Which color is more predominant?",
        "Who is the author?",
    ]
    private static let testSetupData = ChatPdfSetupData(summary: testSummary,
                                                        suggestedQuestions: testSuggestedQuestions)
    private static let testInitParams = ChatPdfInitParams(chatPdfRef: testRef,
                                                                 setupData: testSetupData)
    private static let testParameters = ChatPdfViewModel.Parameters(chatPdfInitParams: testInitParams)

    static var previews: some View {
        let _ = Container.shared.chatPdfManager.register { ChatPdfManagerMock() }
        ChatPdfView(viewModel: Container.shared.chatPdfViewModel(self.testParameters))
    }
}
