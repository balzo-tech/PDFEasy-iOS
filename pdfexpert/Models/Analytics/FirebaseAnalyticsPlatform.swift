//
//  FirebaseAnalyticsPlatform.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/09/2020.
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

class FirebaseAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .reportScreen(let screen):
            self.sendEvent(withEventName: AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: screen.name])
        case .reportNonFatalError(let error):
            Crashlytics.crashlytics().record(error: error.nsError)
        default:
            self.sendEvent(withEventName: event.customEventName, parameters: event.parameters)
        }
    }
    
    // MARK: - Private Methods
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }
}
