//
//  FirebaseAnalyticsPlatform.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/09/2020.
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

private enum FirebaseEventCustomName: String {
    case onboardingCompleted = "onboarding_completed"
}

class FirebaseAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .onboardingCompleted(let results):
            self.onboardingCompleted(results)
        }
    }
    
    // MARK: - Private Methods
    
    private func onboardingCompleted(_ results: [OnboardingQuestion: OnboardingOption]) {
        let parameters: [String: String] = Dictionary(uniqueKeysWithValues: results
            .map { key, value in (key.trackingParameterKey, value.trackingParameterValue) })
        self.sendEvent(withEventName: FirebaseEventCustomName.onboardingCompleted.rawValue,
                       parameters: parameters)
    }
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }
    
    private func reportNonFatalError(_ nsError: NSError) {
        Crashlytics.crashlytics().record(error: nsError)
    }
}
