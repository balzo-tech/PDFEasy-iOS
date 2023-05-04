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
    case pdfEditCompleted = "pdf_edit_completed"
    case pdfShared = "pdf_shared"
}

private enum FirebaseEventCustomParameters: String {
    case quality = "quality"
    case marginOption = "margin_option"
}

class FirebaseAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .onboardingCompleted(let results):
            self.onboardingCompleted(results)
        case .pdfEditCompleted(let marginsOption, let qualityValue):
            self.sendEvent(withEventName: FirebaseEventCustomName.pdfEditCompleted.rawValue,
                           parameters: [
                            FirebaseEventCustomParameters.marginOption.rawValue: marginsOption,
                            FirebaseEventCustomParameters.quality.rawValue: qualityValue
                           ])
        case .pdfShared(let marginsOption, let qualityValue):
            self.sendEvent(withEventName: FirebaseEventCustomName.pdfShared.rawValue,
                           parameters: [
                            FirebaseEventCustomParameters.marginOption.rawValue: marginsOption,
                            FirebaseEventCustomParameters.quality.rawValue: qualityValue
                           ])
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

extension MarginsOption {
    var trackingParameterValue: String {
        switch self {
        case .noMargins: return "no_margins"
        case .mediumMargins: return "medium_margins"
        case .heavyMargins: return "heavy_margins"
        }
    }
}
