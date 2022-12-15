//
//  FirebaseAnalyticsPlatform.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 15/12/22.
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

private enum FirebaseEventCustomName: String {
    case switchTab = "tab_switch"
    case pushNotificationsPermissionChanged = "pushnotifications_permission_changed"
}

private enum FirebaseErrorDomain {
    case serverError(requestName: String)
    case healthError(errorName: String)
    
    var stringValue: String {
        switch self {
        case .serverError(let requestName): return "Server Error - \(requestName)"
        case .healthError(let errorName): return "Health Error - \(errorName)"
        }
    }
}

private enum FirebaseErrorCustomUserInfo: String {
    case networkRequestUrl = "network_request_url"
    case networkErrorType = "network_error_type"
    case networkRequestBody = "network_request_body"
    case networkResponseBody = "network_response_body"
    case networkUnderlyingError = "network_underlying_error"
    case healthUnderlyingError = "health_underlying_error"
}

class FirebaseAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .setUserID(let userID):
            self.setUserID(userID)
        case .setUserPropertyString(let value, let name):
            self.setUserPropertyString(value, forName: name)
        case .recordScreen(let screenName, let screenClass):
            self.sendRecordScreen(screenName: screenName, screenClass: screenClass)
        case .notificationPermissionChanged(let status):
            self.notificationPermissionChanged(status)
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    // MARK: User
    private func setUserID(_ userID: String) {
        Analytics.setUserID(userID)
    }
    
    func setUserPropertyString(_ value: String?, forName: String) {
        Analytics.setUserProperty(value, forName: forName)
    }
    
    // MARK: Onboarding
  
    
    // MARK: Permission

    func notificationPermissionChanged(_ allow: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.pushNotificationsPermissionChanged.rawValue,
                       parameters: [AnalyticsParameter.status.rawValue: allow])
    }
    
    // MARK: Screens
    
    private func sendRecordScreen(screenName: String, screenClass: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: ["screenName":screenName])
    }
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }
        
    private func reportNonFatalError(withDomain domain: FirebaseErrorDomain, statusCode: Int, userInfo: [String: Any]? = nil) {
        self.reportNonFatalError(NSError(domain: domain.stringValue, code: statusCode, userInfo: userInfo))
    }
    
    private func reportNonFatalError(_ nsError: NSError) {
        Crashlytics.crashlytics().record(error: nsError)
    }
}
