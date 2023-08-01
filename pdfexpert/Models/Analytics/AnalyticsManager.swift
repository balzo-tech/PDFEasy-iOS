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
    case chatPdfDeletionFailed
}

enum AnalyticsPdfInputType {
    case camera, gallery, fileImage, file, scan, appExtension, scanPdf, filePdf, scanFillForm, fileFillForm, scanSign, fileSign, fileFillWidget
}

enum AnalyticsScreen {
    case onboarding, home, files, chatPdfSelection, settings, subscription, importTutorial, signature, fillForm, fillWidget, chatPdf, compressionPicker
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
    case pdfRenamed
    case passwordAdded
    case passwordRemoved
    case compressionOptionChanged(compressionOption: CompressionOption)
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
    case pdfSaved
    case pdfShared
    case chatPdfSelectionActionChosen
    case chatPdfSelectionFullActionChosen(importOption: ImportOption?)
    case chatPdfSelectionFullActionCompleted(importOption: ImportOption?, fileExtension: String?)
    case chatPdfMessageSent
    case reportScreen(_ screen: AnalyticsScreen)
    case reportNonFatalError(_ error: AnalyticsError)
}

protocol AnalyticsManager {
    func track(event: AnalyticsEvent)
}
