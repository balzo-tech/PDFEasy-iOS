//
//  PreReviewPopupLowRateView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/08/23.
//

import SwiftUI

typealias PreReviewLowRateSendFeedbackCallback = ((String) -> ())

struct PreReviewPopupLowRateView: View {
    
    @Binding var isPresenting: Bool
    let onSendFeedback: PreReviewLowRateSendFeedbackCallback
    
    @State var feedbackText: String
    @State var remainingCharactersText: String
    
    init(isPresenting: Binding<Bool>,
         initialFeedbackText: String = "",
         onSendFeedback: @escaping PreReviewLowRateSendFeedbackCallback) {
        self._isPresenting = isPresenting
        self.onSendFeedback = onSendFeedback
        self._feedbackText = .init(initialValue: initialFeedbackText)
        self._remainingCharactersText = .init(initialValue: Self.getRemainigCharactersText(forFeedbackText: initialFeedbackText))
    }
    
    var body: some View {
        ZStack {
            self.getCloseButton(
                color: ColorPalette.primaryText,
                leftSide: false,
                padding: 12
            ) {
                self.isPresenting = false
            }
            VStack(spacing: 0) {
                Spacer().frame(height: 12)
                Image("review_low_rate")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .foregroundColor(ColorPalette.extra)
                Spacer().frame(height: 30)
                Text("Your opinion matter to us!")
                    .font(forCategory: .headline)
                    .foregroundColor(ColorPalette.primaryText)
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 8)
                Text("Would you like to share your feedback with us to improve the app?")
                    .font(forCategory: .body2)
                    .foregroundColor(ColorPalette.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 18)
                VStack(spacing: 0) {
                    ZStack {
                        TextEditor(text: self.$feedbackText)
                            .font(forCategory: .caption1)
                            .foregroundColor(ColorPalette.primaryText)
                            .scrollContentBackground(.hidden)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(ColorPalette.primaryBG, lineWidth: 1))
                            .onChange(of: self.feedbackText) { newValue in
                                let maxLength = K.Review.FeedbackMaxCharacters
                                if newValue.count > maxLength  {
                                    self.feedbackText = String(newValue.prefix(maxLength))
                                }
                                self.remainingCharactersText = Self.getRemainigCharactersText(forFeedbackText: self.feedbackText)
                            }
                        if self.feedbackText.isEmpty {
                            VStack {
                                Text("Write your feedback here")
                                    .font(forCategory: .caption1)
                                    .foregroundColor(ColorPalette.thirdText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                            }
                            .padding(.leading, 6)
                            .padding(.top, 8)
                        }
                        VStack(spacing: 0) {
                            Spacer()
                            Text(self.remainingCharactersText)
                                .font(forCategory: .caption2)
                                .foregroundColor(ColorPalette.thirdText)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 6)
                                .padding(.bottom, 8)
                        }
                    }
                    .frame(height: 100)
                }
                Spacer().frame(height: 20)
                self.getDefaultButton(text: "Send Feedback") {
                    self.onSendFeedback(self.feedbackText)
                }
            }
            .padding(16)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(ColorPalette.secondaryBG)
        .cornerRadius(8)
    }
    
    private static func getRemainigCharactersText(forFeedbackText feedbackText: String) -> String {
        let maxLength = K.Review.FeedbackMaxCharacters
        let remainingCharacters = feedbackText.count
        return "\(remainingCharacters)/\(maxLength)"
    }
}

extension View {
    func preReviewLowRatePopup(
        isPresenting: Binding<Bool>,
        onSendFeedback: @escaping PreReviewLowRateSendFeedbackCallback
    ) -> some View {
        self.popup(isPresenting: isPresenting,
                   popupContent: { PreReviewPopupLowRateView(isPresenting: isPresenting,
                                                             onSendFeedback: onSendFeedback) })
    }
}

struct PreReviewPopupLowRateView_Previews: PreviewProvider {
    static var previews: some View {
        PreReviewPopupLowRateView(
            isPresenting: .constant(true),
            onSendFeedback: { result in print("Feedback: \(result)") }
        )
    }
}
