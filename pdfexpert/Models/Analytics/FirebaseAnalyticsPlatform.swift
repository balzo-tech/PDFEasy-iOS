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
    case compressionOption = "compression_option"
    case marginOption = "margin_option"
    case homeActionType = "home_action_type"
    case importOption = "import_option"
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

extension FileSource {
    var trackingParameterValue: String {
        switch self {
        case .google: return "google_drive"
        case .dropbox: return "dropbox"
        case .icloud: return "iCloud"
        case .files: return "files"
        }
    }
}

extension AnalyticsScreen {
    var name: String {
        switch self {
        case .onboarding: return "Onboarding"
        case .home: return "Home"
        case .files: return "File"
        case .chatPdfSelection: return "ChatPdfSelection"
        case .settings: return "Settings"
        case .subscription: return "Subscription"
        case .importTutorial: return "ImportTutorial"
        case .signature: return "Signature"
        case .signaturePicker: return "SignaturePicker"
        case .fillForm: return "FillForm"
        case .fillWidget: return "FillWidget"
        case .chatPdf: return "ChatPdf"
        case .compressionPicker: return "CompressionPicker"
        case .sortPdf: return "SortPdf"
        case .pageRangeEditor: return "PageRangeEditor"
        case .reader: return "Reader"
        case .pageSelection: return "PageSelection"
        }
    }
}

extension AnalyticsEvent {
    var firebaseCustomEventName: String {
        switch self {
        case .appTrackingTransparancyAuthorized: return "tracking_authorized"
        case .checkoutCompleted: return "checkout_completed"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingSkipped: return "onboarding_skipped"
        case .homeActionChosen: return "home_action_chosen"
        case .homeFullActionChosen: return "home_full_action_chosen"
        case .homeFullActionCompleted: return "home_full_action_completed"
        case .pageAdded: return "page_added"
        case .pageRemoved: return "page_remove"
        case .pdfRenamed: return "pdf_renamed"
        case .passwordAdded: return "password_added"
        case .passwordRemoved: return "password_remove"
        case .compressionOptionChanged: return "compression_option_changed"
        case .pdfMerge: return "pdf_merge"
        case .pdfSplit: return "pdf_split"
        case .existingPdfOpened: return "existing_pdf_opened"
        case .existingPdfRemoved: return "existing_pdf_removed"
        case .importTutorialCompleted: return "import_tutorial_completed"
        case .pdfSaved: return "pdf_saved"
        case .pdfShared: return "pdf_shared"
        case .signatureCreated: return "signature_created"
        case .signatureAdded: return "signature_added"
        case .signatureRemoved: return "signature_removed"
        case .signaturesConfirmed: return "signatures_confirmed"
        case .signatureFileSaved: return "signatures_file_saved"
        case .signatureFileDeleted: return "signatures_file_deleted"
        case .textAnnotationAdded: return "text_annotation_added"
        case .textAnnotationRemoved: return "text_annotation_removed"
        case .annotationsConfirmed: return "annotations_confirmed"
        case .fillWidgetCancelled: return "fill_widget_cancelled"
        case .fillWidgetConfirmed: return "fill_widget_confirmed"
        case .chatPdfSelectionActionChosen: return "chat_pdf_selection_action_chosen"
        case .chatPdfSelectionFullActionChosen: return "chat_pdf_selection_full_action_chosen"
        case .chatPdfSelectionFullActionCompleted: return "chat_pdf_selection_full_action_completed"
        case .chatPdfMessageSent: return "chat_pdf_message_sent"
        case .subscriptionShown: return "subscription_shown"
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
        case .homeActionChosen(let homeAction):
            return [FirebaseEventCustomParameters.homeActionType.rawValue: homeAction.trackingParameterValue]
        case .homeFullActionChosen(let homeAction, let importOption):
            var parameters = [FirebaseEventCustomParameters.homeActionType.rawValue: homeAction.trackingParameterValue]
            if let importOption = importOption {
                parameters[FirebaseEventCustomParameters.importOption.rawValue] = importOption.trackingParameterValue
            }
            return parameters
        case .homeFullActionCompleted(let homeAction, let importOption, let fileExtension):
            var parameters = [FirebaseEventCustomParameters.homeActionType.rawValue: homeAction.trackingParameterValue]
            if let fileExtension = fileExtension {
                parameters[FirebaseEventCustomParameters.pdfInputTypeExtension.rawValue] = fileExtension
            }
            if let importOption = importOption {
                parameters[FirebaseEventCustomParameters.importOption.rawValue] = importOption.trackingParameterValue
            }
            return parameters
        case .pageAdded(let pdfInputType, let fileExtension):
            var parameters = [FirebaseEventCustomParameters.pdfInputType.rawValue: pdfInputType.trackingParameterValue]
            if let fileExtension = fileExtension {
                parameters[FirebaseEventCustomParameters.pdfInputTypeExtension.rawValue] = fileExtension
            }
            return parameters
        case .onboardingCompleted: return nil
        case .onboardingSkipped: return nil
        case .pageRemoved: return nil
        case .pdfRenamed: return nil
        case .passwordAdded: return nil
        case .passwordRemoved: return nil
        case .compressionOptionChanged(let compressionOption):
            return [FirebaseEventCustomParameters.compressionOption.rawValue: compressionOption.trackingParameterValue]
        case .pdfMerge: return nil
        case .pdfSplit: return nil
        case .existingPdfOpened: return nil
        case .existingPdfRemoved: return nil
        case .importTutorialCompleted: return nil
        case .textAnnotationAdded: return nil
        case .textAnnotationRemoved: return nil
        case .annotationsConfirmed: return nil
        case .signatureCreated: return nil
        case .signatureAdded: return nil
        case .signatureRemoved: return nil
        case .signaturesConfirmed: return nil
        case .signatureFileSaved: return nil
        case .signatureFileDeleted: return nil
        case .fillWidgetCancelled: return nil
        case .fillWidgetConfirmed: return nil
        case .pdfSaved: return nil
        case .pdfShared: return nil
        case .chatPdfSelectionActionChosen: return nil
        case .chatPdfSelectionFullActionChosen(let importOption):
            var parameters: [String: Any] = [:]
            if let importOption = importOption {
                parameters[FirebaseEventCustomParameters.importOption.rawValue] = importOption.trackingParameterValue
            }
            return parameters
        case .chatPdfSelectionFullActionCompleted(let importOption, let fileExtension):
            var parameters: [String: Any] = [:]
            if let fileExtension = fileExtension {
                parameters[FirebaseEventCustomParameters.pdfInputTypeExtension.rawValue] = fileExtension
            }
            if let importOption = importOption {
                parameters[FirebaseEventCustomParameters.importOption.rawValue] = importOption.trackingParameterValue
            }
            return parameters
        case .chatPdfMessageSent: return nil
        case .subscriptionShown: return nil
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
        case .chatPdfDeletionFailed: return "Pdf uploaded to Chat Pdf has not be deleted"
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
        case .scanPdf: return "scan_pdf"
        case .filePdf: return "file_pdf"
        case .scanFillForm: return "scan_fill_form"
        case .fileFillForm: return "file_fill_form"
        case .scanSign: return "scan_sign"
        case .fileSign: return "file_sign"
        case .fileFillWidget: return "file_fill_widget"
        }
    }
}

fileprivate extension HomeAction {
    
    var trackingParameterValue: String {
        switch self {
        case .appExtension: return "app_extension"
        case .imageToPdf: return "image_to_pdf"
        case .wordToPdf: return "word_to_pdf"
        case .excelToPdf: return "excel_to_pdf"
        case .powerpointToPdf: return "powerpoint_to_pdf"
        case .scan: return "scan"
        case .merge: return "merge"
        case .split: return "split"
        case .sign: return "sign"
        case .formFill: return "form_fill"
        case .addText: return "add_text"
        case .createPdf: return "create_pdf"
        case .importPdf: return "import_pdf"
        case .readPdf: return "read_pdf"
        case .removePassword: return "remove_password"
        case .addPassword: return "add_password"
        }
    }
}

fileprivate extension ImportOption {
    
    var trackingParameterValue: String {
        switch self {
        case .camera: return "camera"
        case .gallery: return "gallery"
        case .scan: return "scan"
        case .file(let fileSource):
            switch fileSource {
            case .google: return "google_drive"
            case .dropbox: return "dropbox"
            case .icloud: return "icloud"
            case .files: return "files"
            }
        }
    }
}

fileprivate extension CompressionOption {
    
    var trackingParameterValue: String {
        switch self {
        case .noCompression: return "no_compression"
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }
}
