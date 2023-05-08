//
//  AnalyticsManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

enum AnalyticsError {
    case shareExtensionPdfMissingRawData
    case shareExtensionPdfCannotDecode
}

enum AnalyticsEvent {
    case onboardingCompleted(results: [OnboardingQuestion: OnboardingOption])
    case pdfEditCompleted(marginsOption: MarginsOption, qualityValue: CGFloat)
    case pdfShared(marginsOption: MarginsOption, qualityValue: CGFloat)
    case reportNonFatalError(_ error: AnalyticsError)
}

protocol AnalyticsManager {
    func track(event: AnalyticsEvent)
}
