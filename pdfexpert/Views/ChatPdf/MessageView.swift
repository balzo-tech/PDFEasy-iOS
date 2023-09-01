//
//  MessageView.swift
//  ChattingAPP
//
//  Created by kz on 02/02/2023.
//

import SwiftUI
import Factory

struct MessageView: View {
    
    let message: ChatPdfMessage
    let onSuggestedQuestionTapped: ((String) -> ())
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: self.message.alignment){
                    switch self.message.type {
                    case .text:
                        let output = self.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(output)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(self.message.textColor)
                            .font(forCategory: .caption1)
                    case .indicator:
                        MessageIndicatorView()
                    }
                }
                if self.message.suggestedQuestions.count > 0 {
                    Spacer().frame(height: 16)
                    Text("Suggested questions:")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(self.message.textColor)
                        .font(forCategory: .caption1)
                    Spacer().frame(height: 16)
                    ForEach(self.message.suggestedQuestions, id:\.self) { suggestedQuestion in
                        Text(suggestedQuestion)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(ColorPalette.secondaryText)
                            .font(FontCategory.caption1.font.bold())
                            .onTapGesture {
                                self.onSuggestedQuestionTapped(suggestedQuestion)
                            }
                        Spacer().frame(height: 16)
                    }
                }
            }
            .padding([.top, .bottom])
            .padding([.leading, .trailing], 16)
            Spacer()
        }
        .background(RoundedCorner(radius: 16, corners: self.message.roundedCorners)
            .fill(self.message.backgroundColor))
        .shadow(radius: self.message.shadowRadius)
        .padding([.leading], self.message.paddingLeading)
        .padding([.trailing], self.message.paddingTrailing)
    }
}

fileprivate extension ChatPdfMessage {
    
    var backgroundColor: Color {
        switch self.role {
        case .user: return ColorPalette.secondaryText
        case .assistant: return ColorPalette.primaryText
        }
    }
    
    var textColor: Color {
        switch self.role {
        case .user: return ColorPalette.primaryText
        case .assistant: return ColorPalette.primaryBG
        }
    }
    
    var shadowRadius: CGFloat {
        switch self.role {
        case .user: return 0.0
        case .assistant: return 0.5
        }
    }
    
    var alignment: VerticalAlignment {
        switch self.role {
        case .user: return .center
        case .assistant: return .top
        }
    }
    
    var paddingLeading: CGFloat {
        switch self.role {
        case .user: return 60
        case .assistant: return 16
        }
    }
    
    var paddingTrailing: CGFloat {
        switch self.role {
        case .user: return 16
        case .assistant: return 60
        }
    }
    
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
            VStack {
                MessageView(
                    message: ChatPdfMessage(role: .assistant, type: .text, content: "This text explains in detail the meaning of life, without ambiguities, questionable assumptions or subjective points of view of any kind. The author also warns the reader that fully reading this text will cause an invitable transcendence to a new state of existence, and thus doing so only if truly prepared.", suggestedQuestions: [
                        "Can you give me a hint about the meaning of life, while avoiding transcendence?",
                        "Can I use the meaning of life for commercial purposes?",
                        "Who is the author?"
                    ]),
                    onSuggestedQuestionTapped: { print("Suggested question: '\($0)'") }
                )
                .padding()
                .previewDisplayName("Introductory Message")
                MessageView(
                    message: ChatPdfMessage(role: .user, type: .text, content: "Test Message"),
                    onSuggestedQuestionTapped: { print("Suggested question: '\($0)'") }
                )
                .padding()
                .previewDisplayName("User Message")
                MessageView(
                    message: ChatPdfMessage(role: .assistant, type: .text, content: "Test Message"),
                    onSuggestedQuestionTapped: { print("Suggested question: '\($0)'") }
                )
                .padding()
                .previewDisplayName("Chat Bot Message")
                MessageView(
                    message: ChatPdfMessage(role: .assistant, type: .text, content: "I guess you guys aren't ready for that, yet. But your kids are gonna love it"),
                    onSuggestedQuestionTapped: { print("Suggested question: '\($0)'") }
                )
                .padding()
                MessageView(
                    message: ChatPdfMessage(role: .assistant, type: .text, content: "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam eaque ipsa, quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt, explicabo. Nemo enim ipsam voluptatem, quia voluptas sit, aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos, qui ratione voluptatem sequi nesciunt, neque porro quisquam est, qui dolorem ipsum, quia dolor sit, amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt, ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur?"),
                    onSuggestedQuestionTapped: { print("Suggested question: '\($0)'") }
                )
                .padding()
            }
            .previewLayout(PreviewLayout.fixed(width: 500, height: 1500))
        }
    }
}

