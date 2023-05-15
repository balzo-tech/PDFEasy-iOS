//
//  AnalyticsManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

enum AnalyticsError {
    case shareExtensionPdfMissingRawData
    case shareExtensionPdfExistingUnexpectedRawData
    case shareExtensionPdfCannotDecode
    case shareExtensionPdfInvalidPasswordForLockedFile
    case shareExtensionPdfMissingDataForUnlockedFile
    case shareExtensionPdfDecryptionFailed
    case shareExtensionPdfCannotDecodeDecryptedData
}

enum AnalyticsPdfInputType {
    case camera, gallery, file, word, scan, appExtension
}

enum AnalyticsScreen {
    case convert, files, settings, subscription, importTutorial
}

enum AnalyticsEvent {
    case onboardingCompleted(results: [OnboardingQuestion: OnboardingOption])
    case conversionToPdfChosen(pdfInputType: AnalyticsPdfInputType)
    case conversionToPdfCompleted(pdfInputType: AnalyticsPdfInputType)
    case pageAdded(pdfInputType: AnalyticsPdfInputType)
    case pageRemoved
    case passwordAdded
    case passwordRemoved
    case pdfListShown
    case existingPdfOpened
    case existingPdfRemoved
    case importTutorialCompleted
    case pdfEditCompleted(marginsOption: MarginsOption, compressionValue: CGFloat)
    case pdfShared(marginsOption: MarginsOption?, compressionValue: CGFloat?)
    case reportScreen(_ screen: AnalyticsScreen)
    case reportNonFatalError(_ error: AnalyticsError)
}

protocol AnalyticsManager {
    func track(event: AnalyticsEvent)
}
