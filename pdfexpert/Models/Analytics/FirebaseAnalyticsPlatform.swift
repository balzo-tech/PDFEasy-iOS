//
//  FirebaseAnalyticsPlatform.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/09/2020.
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

private enum FirebaseEventCustomParameters: String {
    case compression = "compression"
    case marginOption = "margin_option"
    case pdfInputType = "pdf_input_type"
    case pdfInputTypeExtension = "pdf_input_type_extension"
    case productId = "product_identifier"
    case productPrice = "product_price"
    case subscriptionPlanIsFreeTrial = "subscription_is_free_trial"
}

class FirebaseAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .reportNonFatalError(let error):
            Crashlytics.crashlytics().record(error: error.nsError)
        default:
            self.sendEvent(withEventName: event.firebaseCustomEventName, parameters: event.firebaseParameters)
        }
    }
    
    // MARK: - Private Methods
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
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

extension AnalyticsScreen {
    var name: String {
        switch self {
        case .onboarding: return "Onboarding"
        case .home: return "Home"
        case .files: return "File"
        case .settings: return "Settings"
        case .subscription: return "Subscription"
        case .importTutorial: return "ImportTutorial"
        case .signature: return "Signature"
        case .fillForm: return "FillForm"
        }
    }
}

extension AnalyticsEvent {
    var firebaseCustomEventName: String {
        switch self {
        case .appTrackingTransparancyAuthorized: return "tracking_authorized"
        case .checkoutCompleted: return "checkout_completed"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingTutorialCompleted: return "onboarding_tutorial_completed"
        case .onboardingTutorialSkipped: return "onboarding_tutorial_skipped"
        case .conversionToPdfChosen: return "conversion_to_pdf_chosen"
        case .conversionToPdfCompleted: return "conversion_to_pdf_completed"
        case .pageAdded: return "page_added"
        case .pageRemoved: return "page_remove"
        case .passwordAdded: return "password_added"
        case .passwordRemoved: return "password_remove"
        case .pdfListShown: return "pdf_list_shown"
        case .existingPdfOpened: return "existing_pdf_opened"
        case .existingPdfRemoved: return "existing_pdf_removed"
        case .importTutorialCompleted: return "import_tutorial_completed"
        case .pdfEditCompleted: return "pdf_edit_completed"
        case .pdfShared: return "pdf_shared"
        case .signatureCreated: return "signature_created"
        case .signatureAdded: return "signature_added"
        case .textAnnotationAdded: return "text_annotation_added"
        case .textAnnotationRemoved: return "text_annotation_removed"
        case .annotationsConfirmed: return "annotations_confirmed"
        case .reportScreen: return AnalyticsEventScreenView
        case .reportNonFatalError: return ""
        }
    }
    
    var firebaseParameters: [String: Any]? {
        switch self {
        case .appTrackingTransparancyAuthorized: return nil
        case .checkoutCompleted(let subscriptionPlanProduct):
            return [
                FirebaseEventCustomParameters.productId.rawValue: subscriptionPlanProduct.id,
                FirebaseEventCustomParameters.productPrice.rawValue: subscriptionPlanProduct.displayPrice,
                FirebaseEventCustomParameters.subscriptionPlanIsFreeTrial.rawValue: subscriptionPlanProduct.subscription?.introductoryOffer?.paymentMode == .freeTrial
            ]
        case .onboardingCompleted(let results):
            return Dictionary(uniqueKeysWithValues: results
                .map { key, value in (key.trackingParameterKey, value.trackingParameterValue) })
        case .conversionToPdfChosen(let pdfInputType):
            return [FirebaseEventCustomParameters.pdfInputType.rawValue: pdfInputType.trackingParameterValue]
        case .conversionToPdfCompleted(let pdfInputType, let fileExtension):
            var parameters = [FirebaseEventCustomParameters.pdfInputType.rawValue: pdfInputType.trackingParameterValue]
            if let fileExtension = fileExtension {
                parameters[FirebaseEventCustomParameters.pdfInputTypeExtension.rawValue] = fileExtension
            }
            return parameters
        case .pageAdded(let pdfInputType, let fileExtension):
            var parameters = [FirebaseEventCustomParameters.pdfInputType.rawValue: pdfInputType.trackingParameterValue]
            if let fileExtension = fileExtension {
                parameters[FirebaseEventCustomParameters.pdfInputTypeExtension.rawValue] = fileExtension
            }
            return parameters
        case .onboardingTutorialCompleted: return nil
        case .onboardingTutorialSkipped: return nil
        case .pageRemoved: return nil
        case .passwordAdded: return nil
        case .passwordRemoved: return nil
        case .pdfListShown: return nil
        case .existingPdfOpened: return nil
        case .existingPdfRemoved: return nil
        case .importTutorialCompleted: return nil
        case .textAnnotationAdded: return nil
        case .textAnnotationRemoved: return nil
        case .annotationsConfirmed: return nil
        case .signatureCreated: return nil
        case .signatureAdded: return nil
        case .pdfEditCompleted(let marginsOption, let compressionValue):
            return [
             FirebaseEventCustomParameters.marginOption.rawValue: marginsOption.trackingParameterValue,
             FirebaseEventCustomParameters.compression.rawValue: compressionValue
            ]
        case .pdfShared(let marginsOption, let compressionValue):
            var parameters: [String: Any] = [:]
            if let marginsOption = marginsOption {
                parameters[FirebaseEventCustomParameters.marginOption.rawValue] = marginsOption.trackingParameterValue
            }
            if let compressionValue = compressionValue {
                parameters[FirebaseEventCustomParameters.compression.rawValue] = compressionValue
            }
            return parameters
        case .reportScreen(let screen): return [AnalyticsParameterScreenName: screen.name]
        case .reportNonFatalError: return nil
        }
    }
}

extension AnalyticsError {
    
    var errorDescription: String {
        switch self {
        case .shareExtensionPdfMissingRawData: return "Share Extension Pdf raw data missing while existance flag was true"
        case .shareExtensionPdfExistingUnexpectedRawData: return "Share Extension Pdf raw data but the existance flag was false"
        case .shareExtensionPdfCannotDecode: return "Share Extension Pdf raw data existed but could not be converted to PdfDocument"
        case .shareExtensionPdfInvalidPasswordForLockedFile: return "Share Extension Pdf cannot be unlocked with the stored password"
        case .shareExtensionPdfMissingDataForUnlockedFile: return "Share Extension Pdf was unlocked but failed to provide data"
        case .shareExtensionPdfDecryptionFailed: return "Share Extension Pdf was unlocked but could not be decrypted"
        case .shareExtensionPdfCannotDecodeDecryptedData: return "Share Extension Pdf was decrypted but could not be converted to PdfDocument"
        }
    }
    
    var nsError: NSError {
        let userInfo: [String: Any] = [
            "error_description": self.errorDescription
        ]
        return NSError(domain: "AnalyticsError", code: 0, userInfo: userInfo)
    }
}

fileprivate extension AnalyticsPdfInputType {
    
    var trackingParameterValue: String {
        switch self {
        case .camera: return "camera"
        case .gallery: return "gallery"
        case .fileImage: return "file_image"
        case .file: return "file"
        case .scan: return "scan"
        case .appExtension: return "app_extension"
        case .pdf: return "pdf"
        case .scanFillForm: return "scan_fill_form"
        case .fileFillForm: return "file_fill_form"
        }
    }
}
