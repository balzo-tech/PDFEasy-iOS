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
    case camera, gallery, fileImage, file, scan, appExtension, scanPdf, filePdf, scanFillForm, fileFillForm, scanSign, fileSign, fileFillWidget
}

enum AnalyticsScreen {
    case onboarding, home, files, chatPdfSelection, settings, subscription, importTutorial, signature, fillForm, fillWidget, chatPdf
}

enum AnalyticsEvent {
    case appTrackingTransparancyAuthorized
    case checkoutCompleted(subscriptionPlanProduct: Product)
    case onboardingCompleted
    case onboardingSkipped
    case homeActionChosen(homeAction: HomeAction)
    case homeFullActionChosen(homeAction: HomeAction, importOption: ImportOption?)
    case homeFullActionCompleted(homeAction: HomeAction, importOption: ImportOption?, fileExtension: String?)
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
    case fillWidgetCancelled
    case fillWidgetConfirmed
    case pdfEditCompleted(marginsOption: MarginsOption, compressionValue: CGFloat)
    case pdfShared(marginsOption: MarginsOption?, compressionValue: CGFloat?)
    case chatPdfSelectionFullActionChosen(importOption: ImportOption?)
    case chatPdfSelectionFullActionCompleted(importOption: ImportOption?, fileExtension: String?)
    case reportScreen(_ screen: AnalyticsScreen)
    case reportNonFatalError(_ error: AnalyticsError)
}

protocol AnalyticsManager {
    func track(event: AnalyticsEvent)
}
