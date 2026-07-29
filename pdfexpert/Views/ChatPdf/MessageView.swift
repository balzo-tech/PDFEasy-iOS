//
//  MessageView.swift
//  PdfExpert
//
//  One turn of the conversation.
//
//  A bubble is sized by its text and never spans the full width: the gutter the
//  other speaker keeps is what makes a column of text read as a dialogue. The
//  assistant's turn sits on `surface` — it used to be filled with `primaryText`,
//  which in dark mode is very nearly white, and a wall of it was the loudest
//  thing on the screen.
//
//  Suggested questions are buttons, and look like buttons. They used to be blue
//  sentences inside the assistant's bubble with a tap gesture on the text: no
//  affordance that they could be tapped, and a target as tall as a line of type.
//

import SwiftUI

struct MessageView: View {

    let message: ChatPdfMessage
    let onSuggestedQuestionTapped: ((String) -> ())

    /// Width left to the other speaker. Enough that a short answer is clearly
    /// one side of an exchange, not so much that a long one has to wrap early.
    private static let gutter: CGFloat = 56

    var body: some View {
        HStack(spacing: 0) {
            if self.message.role == .user {
                Spacer(minLength: Self.gutter)
            }
            VStack(alignment: self.message.horizontalAlignment, spacing: 10) {
                self.bubble
                if !self.message.suggestedQuestions.isEmpty {
                    self.suggestedQuestions
                }
            }
            if self.message.role == .assistant {
                Spacer(minLength: Self.gutter)
            }
        }
        .padding(.horizontal, 16)
    }

    private var bubble: some View {
        Group {
            switch self.message.type {
            case .text:
                Text(self.message.content.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(forCategory: .body2)
                    .foregroundColor(self.message.textColor)
                    // Answers carry figures and dates worth copying out.
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            case .indicator:
                MessageIndicatorView()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
        .background(
            RoundedCorner(radius: 18, corners: self.message.roundedCorners)
                .fill(self.message.backgroundColor)
        )
    }

    private var suggestedQuestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested questions:")
                .font(forCategory: .caption2)
                .foregroundColor(ColorPalette.textTertiary)
            ForEach(self.message.suggestedQuestions, id: \.self) { suggestedQuestion in
                Button {
                    self.onSuggestedQuestionTapped(suggestedQuestion)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(suggestedQuestion)
                            .font(forCategory: .body2)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up.forward")
                            .font(.caption2)
                    }
                    .foregroundColor(ColorPalette.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(ColorPalette.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

fileprivate extension ChatPdfMessage {

    var backgroundColor: Color {
        switch self.role {
        case .user: return ColorPalette.chatBubbleUser
        case .assistant: return ColorPalette.surface
        }
    }

    var textColor: Color {
        switch self.role {
        case .user: return .white
        case .assistant: return ColorPalette.textPrimary
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self.role {
        case .user: return .trailing
        case .assistant: return .leading
        }
    }

    /// Square on the side the bubble comes from, rounded everywhere else — the
    /// corner that points back at whoever is speaking.
    var roundedCorners: UIRectCorner {
        switch self.role {
        case .user: return [.bottomLeft, .bottomRight, .topLeft]
        case .assistant: return [.bottomLeft, .bottomRight, .topRight]
        }
    }
}

struct MessageView_Previews: PreviewProvider {

    static var previews: some View {
        ScrollView {
            VStack(spacing: 12) {
                MessageView(
                    message: ChatPdfMessage(role: .assistant, type: .text, content: "This text explains in detail the meaning of life, without ambiguities, questionable assumptions or subjective points of view of any kind. The author also warns the reader that fully reading this text will cause an invitable transcendence to a new state of existence, and thus doing so only if truly prepared.", suggestedQuestions: [
                        "Can you give me a hint about the meaning of life, while avoiding transcendence?",
                        "Can I use the meaning of life for commercial purposes?",
                        "Who is the author?"
                    ]),
                    onSuggestedQuestionTapped: { print("Suggested question: '\($0)'") }
                )
                MessageView(
                    message: ChatPdfMessage(role: .user, type: .text, content: "Test Message"),
                    onSuggestedQuestionTapped: { print("Suggested question: '\($0)'") }
                )
                MessageView(
                    message: ChatPdfMessage(role: .assistant, type: .indicator, content: ""),
                    onSuggestedQuestionTapped: { print("Suggested question: '\($0)'") }
                )
            }
            .padding(.vertical, 16)
        }
        .background(ColorPalette.background)
    }
}
