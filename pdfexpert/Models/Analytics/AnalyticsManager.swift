//
//  AnalyticsManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

enum AnalyticsEvent {
    case onboardingCompleted(results: [OnboardingQuestion: OnboardingOption])
}

protocol AnalyticsManager {
    func track(event: AnalyticsEvent)
}
