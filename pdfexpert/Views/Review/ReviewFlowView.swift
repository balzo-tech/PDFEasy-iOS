//
//  ReviewFlowView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/08/23.
//

import SwiftUI

struct ReviewFlowView: ViewModifier {
    
    @ObservedObject var flow: ReviewFlow
    
    @Environment(\.requestReview) var requestReview

    func body(content: Content) -> some View {
        content
            .preReviewPopup(isPresenting: self.$flow.showPreReviewView,
                            onConfirm: { preReviewRate in
                self.flow.onPreReviewRateSelected(preReviewRate: preReviewRate,
                                                  nativeReviewCallback: { self.requestReview() })
            })
            .preReviewLowRatePopup(isPresenting: self.$flow.showLowReviewView,
                                   onSendFeedback: { feedback in
                self.flow.onPreReviewLowRateFeedbackSent(feedback: feedback)
            })
    }
}

extension View {
    func reviewFlowView(flow: ReviewFlow) -> some View {
        self.modifier(ReviewFlowView(flow: flow))
    }
}
