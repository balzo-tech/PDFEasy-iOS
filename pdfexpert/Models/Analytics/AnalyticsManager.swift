//
//  AnalyticsManager.swift
//  PdfExpert
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
    case compress
    case compare
    case backgroundRemoval
    case passportPhoto
    case imageEditor
    case imageCompress
    case memeMaker
    case scan
    case scanReview
    case scanLibrary
}

/// What a finished scan was turned into.
enum AnalyticsScanFormat {
    case pdf
    case image
}

/// What the customer did when they asked to leave the paywall. The exit prompt
/// is only raised while a free trial is still on the table and only once per
/// showing, so `notShown` covers both the second attempt and the case where
/// there is no trial left to offer.
///
/// `accepted` is not an exit at all — the customer stayed and the purchase
/// began — but it is the only way to tell whether the prompt earns its place.
enum AnalyticsPaywallExit {
    case notShown
    case declined
    case accepted
}

/// Why a purchase that started never became a transaction.
///
/// Every case here is an outcome of `Product.purchase`, and together they answer
/// the question `checkout_completed` cannot: of the customers who pressed the
/// button, how many did Apple actually charge. `error` carries the domain and
/// code rather than the message, so the value stays stable across the sixteen
/// languages the app is sold in and carries nothing personal.
enum AnalyticsCheckoutFailure {
    case userCancelled
    case pending
    case verificationFailed
    case unknownResult
    case error(code: String)
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
    case pageDuplicated
    case pageRotated(rotationType: AnalyticsPageRotationType)
    case pdfRenamed
    case passwordAdded
    case passwordRemoved
    case pdfMerge
    case pdfSplit
    case pdfExtract
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
    /// The customer asked to close the paywall. Raised on the way out — and on
    /// `accepted`, on the way back in — so the silent half of `subscriptionShown`
    /// stops being invisible.
    case subscriptionDismissed(exit: AnalyticsPaywallExit)
    /// The button was pressed and Apple's sheet was asked for. The gap between
    /// this and `checkoutCompleted` is where declined cards live.
    case checkoutStarted(subscriptionPlanProduct: Product)
    case checkoutFailed(subscriptionPlanProduct: Product, failure: AnalyticsCheckoutFailure)
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
    case compressionStarted
    case compressionCompleted(preset: CompressionPreset, savedPercent: Int)
    case compareStarted
    case compareCompleted(changedPageCount: Int)
    case backgroundRemovalStarted
    /// `destination` is what the cut-out was actually used for — the number that
    /// says whether the tool ends in a saved file or in a shrug.
    case backgroundRemovalCompleted(style: String, destination: String)
    case passportPhotoStarted(spec: String)
    /// `spec` is the country and document, `outcome` the worst thing the
    /// checklist found. Together they answer the question the feature lives or
    /// dies on: are people getting a photo they are willing to print, and in
    /// which countries are they not.
    case passportPhotoCompleted(spec: String, destination: String, output: String, outcome: String)
    case imageEditStarted
    /// `shape` is which frame people actually crop for; `destination` is
    /// whether the edit ends in a file or in a shrug.
    case imageEditCompleted(shape: String, destination: String)
    /// How many photographs were handed to the tool at once — the number that
    /// says whether this is a one-picture job, as it was built assuming it is not.
    case imageCompressStarted(imageCount: Int)
    /// `quality` and `size` are the two dials, and which of them people move is
    /// the question the tool is there to answer; `savedPercent` says whether the
    /// answer was worth having, `destination` whether it ended in a file.
    case imageCompressCompleted(quality: ImageCompressionQuality,
                                size: ImageCompressionSize,
                                destination: String,
                                savedPercent: Int,
                                imageCount: Int)
    case memeStarted
    /// The tool exists to be shared out of, so `destination` is the whole
    /// experiment: a meme saved to the camera roll is not the same result as
    /// a meme sent to somebody.
    case memeCompleted(lines: Int, template: String, destination: String)
    case folderSaved
    case folderDeleted
    case pdfFiled
    case tagSaved
    case tagDeleted
    case pdfTagged
    case scanPageCaptured(automatic: Bool)
    case scanPageRetaken
    case scanFilterApplied(filter: ScanFilter, appliedToAll: Bool)
    case scanCropAdjusted
    case scanSaved(format: AnalyticsScanFormat, pageCount: Int)
    case reportScreen(_ screen: AnalyticsScreen)
    case reportNonFatalError(_ error: AnalyticsError)
}

protocol AnalyticsManager {
    func track(event: AnalyticsEvent)
}
