//
//  AnalyticsService.swift
//  pdfexpert
//
//  Created by Giuseppe Lapenta on 15/12/22.
//

import Foundation

enum AnalyticsParameter: String {
    case userId
    case screenId = "screen_id"
    case page
    case privacyPolicy
    case termsOfService
    case deviceId = "device_id"
    case accountType = "account_type"
    case option
}

enum AnalyticsScreens: String {
    case openPermissions = "Permissions"
    case privacyPolicy = "PrivacyPolicy"
    case termsOfService = "TermsOfService"
}

enum AnalyticsEvent {
    // Record Page
    case recordScreen(screenName: String, screenClass: String)
    // User
    case setUserID(_ userID: String)
    case setUserPropertyString(_ value: String?, forName: String)
    
    // Onboarding
    case startStudyAction(_ actionType: String)
    case cancelDuringScreeningQuestion(_ questionID: String?)
    case cancelDuringInformedConsent(_ pageID: String)
    case cancelDuringComprehensionQuiz(_ questionID: String)
    case consentAgreed
    case consentDisagreed
    
    // Main App
    case switchTab(_ tabName: String)
    
    // Permission
    case locationPermissionChanged(_ status: String)
    case notificationPermissionChanged(_ status: String)
}

protocol AnalyticsService {
    func track(event: AnalyticsEvent)
}
