//
//  AnalyticsManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation
import StoreKit

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
    case camera, gallery, fileImage, file, scan, appExtension, scanPdf, filePdf, scanFillForm, fileFillForm, scanSign, fileSign
}

enum AnalyticsScreen {
    case onboarding, home, files, settings, subscription, importTutorial, signature, fillForm
}

enum AnalyticsEvent {
    case appTrackingTransparancyAuthorized
    case checkoutCompleted(subscriptionPlanProduct: Product)
    case onboardingCompleted(results: [OnboardingQuestion: OnboardingOption])
    case onboardingTutorialCompleted
    case onboardingTutorialSkipped
    case conversionToPdfChosen(pdfInputType: AnalyticsPdfInputType, fileSource: FileSource?)
    case conversionToPdfCompleted(pdfInputType: AnalyticsPdfInputType, fileSource: FileSource?, fileExtension: String?)
    case pageAdded(pdfInputType: AnalyticsPdfInputType, fileExtension: String?)
    case pageRemoved
    case passwordAdded
    case passwordRemoved
    case pdfListShown
    case existingPdfOpened
    case existingPdfRemoved
    case importTutorialCompleted
    case signatureCreated
    case signatureAdded
    case textAnnotationAdded
    case textAnnotationRemoved
    case annotationsConfirmed
    case pdfEditCompleted(marginsOption: MarginsOption, compressionValue: CGFloat)
    case pdfShared(marginsOption: MarginsOption?, compressionValue: CGFloat?)
    case reportScreen(_ screen: AnalyticsScreen)
    case reportNonFatalError(_ error: AnalyticsError)
}

protocol AnalyticsManager {
    func track(event: AnalyticsEvent)
}
