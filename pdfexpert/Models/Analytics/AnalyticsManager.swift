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

enum AnalyticsPageRotationType {
    case single, all
}

enum AnalyticsScreen {
    case onboarding
    case home
    case files
    case chatPdfSelection
    case settings
    case subscription
    case importTutorial
    case signature
    case signaturePicker
    case fillForm
    case fillWidget
    case chatPdf
    case compressionPicker
    case sortPdf
    case pageRangeEditor
    case reader
    case pageSelection
    case suggestedFields
    case ocr
    case pageNumbers
    case watermark
    case export
    case metadata
    case convert
    case advancedTool
    case webImport
    case markdownImport
    case permissions
    case redact
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
    case pageRotated(rotationType: AnalyticsPageRotationType)
    case pdfRenamed
    case passwordAdded
    case passwordRemoved
    case pdfMerge
    case pdfSplit
    case pdfExtract
    case compressionOptionChanged(compressionOption: CompressionOption)
    case existingPdfOpened
    case existingPdfRemoved
    case importTutorialCompleted
    case signatureCreated
    case signatureAdded
    case signatureRemoved
    case signaturesConfirmed
    case signatureFileSaved
    case signatureFileDeleted
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
    case chatMessageLimitReached
    case subscriptionShown
    case reviewLowRateFeedback(feedback: String)
    case suggestedFieldsSaved
    case ocrStarted
    case ocrCompleted
    case pageNumbersStarted
    case pageNumbersCompleted(position: PageNumberPosition, format: PageNumberFormat)
    case watermarkStarted
    case watermarkCompleted(layout: WatermarkLayout)
    case exportStarted(format: PdfExportFormat)
    case exportCompleted(format: PdfExportFormat)
    case convertStarted(format: PdfConvertFormat)
    case convertCompleted(format: PdfConvertFormat)
    case advancedToolStarted(tool: PdfAdvancedTool)
    case advancedToolCompleted(tool: PdfAdvancedTool)
    case officeConvertCompleted(engine: OfficeConvertEngine)
    case officeConvertFailed(engine: OfficeConvertEngine)
    case officeConvertFallbackOffered
    case webToPdfStarted
    case webToPdfCompleted
    case markdownToPdfCompleted
    case blankPagesRemoved(count: Int)
    case pdfFlattened
    case colorsInverted
    case pdfPermissionsSet(allowsPrinting: Bool, allowsCopying: Bool)
    case redactionStarted
    case redactionCompleted(boxCount: Int, pageCount: Int)
    case annotationAdded(type: PdfAnnotationType)
    case annotationsSaved
    case pdfMetadataUpdated
    case folderSaved
    case folderDeleted
    case pdfFiled
    case tagSaved
    case tagDeleted
    case pdfTagged
    case reportScreen(_ screen: AnalyticsScreen)
    case reportNonFatalError(_ error: AnalyticsError)
}

protocol AnalyticsManager {
    func track(event: AnalyticsEvent)
}
