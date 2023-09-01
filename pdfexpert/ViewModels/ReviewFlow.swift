//
//  ReviewFlow.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/08/23.
//

import Foundation
import Factory
import SwiftUI
import StoreKit

extension Container {
    var reviewFlow: Factory<ReviewFlow> {
        self { ReviewFlow() }
    }
}

class ReviewFlow: ObservableObject {
    
    @Published var showPreReviewView: Bool = false
    @Published var showLowReviewView: Bool = false
    
    @Injected(\.analyticsManager) var analyticsManager
    @Injected(\.cacheManager) var cacheManager
    @Injected(\.store) var store
    
    private var shouldShow: Bool {
        return self.neverSeenBefore && self.store.isPremium.value
    }
    
    private var neverSeenBefore: Bool {
        #if DEBUG
            if K.Test.Review.ShowAlways {
                return true
            } else {
                return !self.cacheManager.preReviewShown
            }
        #else
            !self.cacheManager.preReviewShown
        #endif
    }
    
    func startFlowIfNeeded() {
        if self.shouldShow {
            self.cacheManager.preReviewShown = true
            self.showPreReviewView = true
        }
    }
    
    @MainActor
    func onPreReviewRateSelected(preReviewRate: Int, nativeReviewCallback: @escaping (() -> ())) {
        Task {
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            self.showPreReviewView = false
            try await Task.sleep(until: .now + .seconds(0.25), clock: .continuous)
            if preReviewRate >= K.Review.MinimumRateForNativePopup {
                nativeReviewCallback()
            } else {
                self.showLowReviewView = true
            }
        }
    }
    
    func onPreReviewLowRateFeedbackSent(feedback: String) {
        self.showLowReviewView = false
        if !feedback.isEmpty {
            self.analyticsManager.track(event: .reviewLowRateFeedback(feedback: feedback))
        }
    }
}
