//
//  AnalyticsDefaultParameters.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 05/09/23.
//

import Foundation

enum AnalyticsEventCustomParameters: String {
    case marginOption = "margin_option"
    case backgroundStyle = "background_style"
    case backgroundDestination = "background_destination"
    case homeActionType = "home_action_type"
    case importOption = "import_option"
    case pdfInputType = "pdf_input_type"
    case pdfInputTypeExtension = "pdf_input_type_extension"
    case productId = "product_identifier"
    case productPrice = "product_price"
    case subscriptionPlanIsFreeTrial = "subscription_is_free_trial"
    case reviewLowRateFeedbackContent = "review_low_rate_feedback_content"
    case screenName = "screen_name"
    case rotationType = "rotation_type"
    case pageNumberPosition = "page_number_position"
    case pageNumberFormat = "page_number_format"
    case watermarkLayout = "watermark_layout"
    case exportFormat = "export_format"
    case convertFormat = "convert_format"
    case advancedTool = "advanced_tool"
    case officeConvertEngine = "office_convert_engine"
    case removedPagesCount = "removed_pages_count"
    case allowsPrinting = "allows_printing"
    case allowsCopying = "allows_copying"
    case redactionBoxCount = "redaction_box_count"
    case redactedPageCount = "redacted_page_count"
    case annotationType = "annotation_type"
    case compressionPreset = "compression_preset"
    case compressionSavedPercent = "compression_saved_percent"
    case changedPageCount = "changed_page_count"
    case scanAutomaticShutter = "scan_automatic_shutter"
    case scanFilter = "scan_filter"
    case scanFilterAppliedToAll = "scan_filter_applied_to_all"
    case scanFormat = "scan_format"
    case scanPageCount = "scan_page_count"
}

extension AnalyticsScanFormat {
    var trackingParameterValue: String {
        switch self {
        case .pdf: return "pdf"
        case .image: return "image"
        }
    }
}

extension OfficeConvertEngine {
    var trackingParameterValue: String {
        switch self {
        case .onDevice: return "on_device"
        case .stirling: return "stirling"
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
        case .sortPdf: return "SortPdf"
        case .pageRangeEditor: return "PageRangeEditor"
        case .reader: return "Reader"
        case .pageSelection: return "PageSelection"
        case .suggestedFields: return "SuggestedFields"
        case .ocr: return "Ocr"
        case .pageNumbers: return "PageNumbers"
        case .watermark: return "Watermark"
        case .export: return "Export"
        case .metadata: return "Metadata"
        case .convert: return "Convert"
        case .advancedTool: return "AdvancedTool"
        case .webImport: return "WebImport"
        case .markdownImport: return "MarkdownImport"
        case .permissions: return "Permissions"
        case .redact: return "Redact"
        case .compress: return "Compress"
        case .compare: return "Compare"
        case .backgroundRemoval: return "BackgroundRemoval"
        case .scan: return "Scan"
        case .scanReview: return "ScanReview"
        case .scanLibrary: return "ScanLibrary"
        }
    }
}

extension AnalyticsEvent {
    var customEventName: String {
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
        case .pageDuplicated: return "page_duplicated"
        case .pageRotated: return "page_rotated"
        case .pdfRenamed: return "pdf_renamed"
        case .passwordAdded: return "password_added"
        case .passwordRemoved: return "password_remove"
        case .pdfMerge: return "pdf_merge"
        case .pdfSplit: return "pdf_split"
        case .pdfExtract: return "pdf_extract"
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
        case .chatMessageLimitReached: return "chat_message_limit_reached"
        case .subscriptionShown: return "subscription_shown"
        case .reviewLowRateFeedback: return "review_low_rate_feedback"
        case .suggestedFieldsSaved: return "suggested_fields_saved"
        case .ocrStarted: return "ocr_started"
        case .ocrCompleted: return "ocr_completed"
        case .pageNumbersStarted: return "page_numbers_started"
        case .pageNumbersCompleted: return "page_numbers_completed"
        case .watermarkStarted: return "watermark_started"
        case .watermarkCompleted: return "watermark_completed"
        case .exportStarted: return "export_started"
        case .exportCompleted: return "export_completed"
        case .convertStarted: return "convert_started"
        case .convertCompleted: return "convert_completed"
        case .advancedToolStarted: return "advanced_tool_started"
        case .advancedToolCompleted: return "advanced_tool_completed"
        case .officeConvertCompleted: return "office_convert_completed"
        case .officeConvertFailed: return "office_convert_failed"
        case .officeConvertFallbackOffered: return "office_convert_fallback_offered"
        case .webToPdfStarted: return "web_to_pdf_started"
        case .webToPdfCompleted: return "web_to_pdf_completed"
        case .markdownToPdfCompleted: return "markdown_to_pdf_completed"
        case .blankPagesRemoved: return "blank_pages_removed"
        case .pdfFlattened: return "pdf_flattened"
        case .colorsInverted: return "colors_inverted"
        case .pdfPermissionsSet: return "pdf_permissions_set"
        case .redactionStarted: return "redaction_started"
        case .redactionCompleted: return "redaction_completed"
        case .annotationAdded: return "annotation_added"
        case .annotationsSaved: return "annotations_saved"
        case .pdfMetadataUpdated: return "pdf_metadata_updated"
        case .compressionStarted: return "compression_started"
        case .compressionCompleted: return "compression_completed"
        case .compareStarted: return "compare_started"
        case .compareCompleted: return "compare_completed"
        case .backgroundRemovalStarted: return "background_removal_started"
        case .backgroundRemovalCompleted: return "background_removal_completed"
        case .folderSaved: return "folder_saved"
        case .folderDeleted: return "folder_deleted"
        case .pdfFiled: return "pdf_filed"
        case .tagSaved: return "tag_saved"
        case .tagDeleted: return "tag_deleted"
        case .pdfTagged: return "pdf_tagged"
        case .scanPageCaptured: return "scan_page_captured"
        case .scanPageRetaken: return "scan_page_retaken"
        case .scanFilterApplied: return "scan_filter_applied"
        case .scanCropAdjusted: return "scan_crop_adjusted"
        case .scanSaved: return "scan_saved"
        case .reportScreen: return "report_screen"
        case .reportNonFatalError: return ""
        }
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .appTrackingTransparancyAuthorized: return nil
        case .checkoutCompleted(let subscriptionPlanProduct):
            return [
                AnalyticsEventCustomParameters.productId.rawValue: subscriptionPlanProduct.id,
                AnalyticsEventCustomParameters.productPrice.rawValue: subscriptionPlanProduct.displayPrice,
                AnalyticsEventCustomParameters.subscriptionPlanIsFreeTrial.rawValue: subscriptionPlanProduct.subscription?.introductoryOffer?.paymentMode == .freeTrial
            ]
        case .homeActionChosen(let homeAction):
            return [AnalyticsEventCustomParameters.homeActionType.rawValue: homeAction.trackingParameterValue]
        case .homeFullActionChosen(let homeAction, let importOption):
            var parameters = [AnalyticsEventCustomParameters.homeActionType.rawValue: homeAction.trackingParameterValue]
            if let importOption = importOption {
                parameters[AnalyticsEventCustomParameters.importOption.rawValue] = importOption.trackingParameterValue
            }
            return parameters
        case .homeFullActionCompleted(let homeAction, let importOption, let fileExtension):
            var parameters = [AnalyticsEventCustomParameters.homeActionType.rawValue: homeAction.trackingParameterValue]
            if let fileExtension = fileExtension {
                parameters[AnalyticsEventCustomParameters.pdfInputTypeExtension.rawValue] = fileExtension
            }
            if let importOption = importOption {
                parameters[AnalyticsEventCustomParameters.importOption.rawValue] = importOption.trackingParameterValue
            }
            return parameters
        case .pageAdded(let pdfInputType, let fileExtension):
            var parameters = [AnalyticsEventCustomParameters.pdfInputType.rawValue: pdfInputType.trackingParameterValue]
            if let fileExtension = fileExtension {
                parameters[AnalyticsEventCustomParameters.pdfInputTypeExtension.rawValue] = fileExtension
            }
            return parameters
        case .onboardingCompleted: return nil
        case .onboardingSkipped: return nil
        case .pageRemoved: return nil
        case .pageDuplicated: return nil
        case .pageRotated(let rotationType):
            return [AnalyticsEventCustomParameters.rotationType.rawValue: rotationType.trackingParameterValue]
        case .pdfRenamed: return nil
        case .passwordAdded: return nil
        case .passwordRemoved: return nil
        case .pdfMerge: return nil
        case .pdfSplit: return nil
        case .pdfExtract: return nil
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
                parameters[AnalyticsEventCustomParameters.importOption.rawValue] = importOption.trackingParameterValue
            }
            return parameters
        case .chatPdfSelectionFullActionCompleted(let importOption, let fileExtension):
            var parameters: [String: Any] = [:]
            if let fileExtension = fileExtension {
                parameters[AnalyticsEventCustomParameters.pdfInputTypeExtension.rawValue] = fileExtension
            }
            if let importOption = importOption {
                parameters[AnalyticsEventCustomParameters.importOption.rawValue] = importOption.trackingParameterValue
            }
            return parameters
        case .chatPdfMessageSent: return nil
        case .chatMessageLimitReached: return nil
        case .subscriptionShown: return nil
        case .reviewLowRateFeedback(let feedback):
            return [AnalyticsEventCustomParameters.reviewLowRateFeedbackContent.rawValue: feedback]
        case .suggestedFieldsSaved: return nil
        case .ocrStarted: return nil
        case .ocrCompleted: return nil
        case .pageNumbersStarted: return nil
        case .pageNumbersCompleted(let position, let format):
            return [
                AnalyticsEventCustomParameters.pageNumberPosition.rawValue: position.trackingParameterValue,
                AnalyticsEventCustomParameters.pageNumberFormat.rawValue: format.trackingParameterValue
            ]
        case .watermarkStarted: return nil
        case .watermarkCompleted(let layout):
            return [AnalyticsEventCustomParameters.watermarkLayout.rawValue: layout.trackingParameterValue]
        case .exportStarted(let format), .exportCompleted(let format):
            return [AnalyticsEventCustomParameters.exportFormat.rawValue: format.trackingParameterValue]
        case .convertStarted(let format), .convertCompleted(let format):
            return [AnalyticsEventCustomParameters.convertFormat.rawValue: format.trackingParameterValue]
        case .advancedToolStarted(let tool), .advancedToolCompleted(let tool):
            return [AnalyticsEventCustomParameters.advancedTool.rawValue: tool.trackingParameterValue]
        case .officeConvertCompleted(let engine), .officeConvertFailed(let engine):
            return [AnalyticsEventCustomParameters.officeConvertEngine.rawValue: engine.trackingParameterValue]
        case .officeConvertFallbackOffered: return nil
        case .webToPdfStarted, .webToPdfCompleted, .markdownToPdfCompleted: return nil
        case .blankPagesRemoved(let count):
            return [AnalyticsEventCustomParameters.removedPagesCount.rawValue: count]
        case .pdfFlattened, .colorsInverted: return nil
        case .pdfPermissionsSet(let allowsPrinting, let allowsCopying):
            return [AnalyticsEventCustomParameters.allowsPrinting.rawValue: allowsPrinting,
                    AnalyticsEventCustomParameters.allowsCopying.rawValue: allowsCopying]
        case .redactionStarted: return nil
        case .redactionCompleted(let boxCount, let pageCount):
            return [AnalyticsEventCustomParameters.redactionBoxCount.rawValue: boxCount,
                    AnalyticsEventCustomParameters.redactedPageCount.rawValue: pageCount]
        case .annotationAdded(let type):
            return [AnalyticsEventCustomParameters.annotationType.rawValue: type.rawValue]
        case .annotationsSaved: return nil
        case .pdfMetadataUpdated: return nil
        case .compressionStarted: return nil
        case .compressionCompleted(let preset, let savedPercent):
            return [AnalyticsEventCustomParameters.compressionPreset.rawValue: preset.trackingParameterValue,
                    AnalyticsEventCustomParameters.compressionSavedPercent.rawValue: savedPercent]
        case .compareStarted: return nil
        case .compareCompleted(let changedPageCount):
            return [AnalyticsEventCustomParameters.changedPageCount.rawValue: changedPageCount]
        case .backgroundRemovalStarted: return nil
        case .backgroundRemovalCompleted(let style, let destination):
            return [AnalyticsEventCustomParameters.backgroundStyle.rawValue: style,
                    AnalyticsEventCustomParameters.backgroundDestination.rawValue: destination]
        case .folderSaved: return nil
        case .folderDeleted: return nil
        case .pdfFiled: return nil
        case .tagSaved: return nil
        case .tagDeleted: return nil
        case .pdfTagged: return nil
        case .scanPageCaptured(let automatic):
            return [AnalyticsEventCustomParameters.scanAutomaticShutter.rawValue: automatic]
        case .scanPageRetaken: return nil
        case .scanFilterApplied(let filter, let appliedToAll):
            return [AnalyticsEventCustomParameters.scanFilter.rawValue: filter.rawValue,
                    AnalyticsEventCustomParameters.scanFilterAppliedToAll.rawValue: appliedToAll]
        case .scanCropAdjusted: return nil
        case .scanSaved(let format, let pageCount):
            return [AnalyticsEventCustomParameters.scanFormat.rawValue: format.trackingParameterValue,
                    AnalyticsEventCustomParameters.scanPageCount.rawValue: pageCount]
        case .reportScreen(let screen):
            return [AnalyticsEventCustomParameters.screenName.rawValue: screen.name]
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

fileprivate extension AnalyticsPageRotationType {

    var trackingParameterValue: String {
        switch self {
        case .single: return "single"
        case .all: return "all"
        }
    }
}

fileprivate extension PageNumberPosition {

    var trackingParameterValue: String {
        switch self {
        case .topLeft: return "top_left"
        case .topCenter: return "top_center"
        case .topRight: return "top_right"
        case .bottomLeft: return "bottom_left"
        case .bottomCenter: return "bottom_center"
        case .bottomRight: return "bottom_right"
        }
    }
}

fileprivate extension PageNumberFormat {

    var trackingParameterValue: String {
        switch self {
        case .simple: return "simple"
        case .ofTotal: return "of_total"
        }
    }
}

fileprivate extension WatermarkLayout {

    var trackingParameterValue: String {
        switch self {
        case .diagonal: return "diagonal"
        case .horizontal: return "horizontal"
        }
    }
}

fileprivate extension PdfExportFormat {

    var trackingParameterValue: String {
        switch self {
        case .imagesPng: return "images_png"
        case .imagesJpeg: return "images_jpeg"
        case .text: return "text"
        case .embeddedImages: return "embedded_images"
        }
    }
}

fileprivate extension PdfConvertFormat {

    var trackingParameterValue: String {
        switch self {
        case .word: return "word"
        case .powerpoint: return "powerpoint"
        case .csv: return "csv"
        }
    }
}

fileprivate extension PdfAdvancedTool {

    var trackingParameterValue: String {
        switch self {
        case .pdfa: return "pdfa"
        case .repair: return "repair"
        case .sanitize: return "sanitize"
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
        case .webToPdf: return "web_to_pdf"
        case .markdownToPdf: return "markdown_to_pdf"
        case .scan: return "scan"
        case .merge: return "merge"
        case .split: return "split"
        case .extractPages: return "extract_pages"
        case .exportPdf: return "export_pdf"
        case .pdfToWord: return "pdf_to_word"
        case .pdfToPowerpoint: return "pdf_to_powerpoint"
        case .pdfToExcel: return "pdf_to_excel"
        case .pdfToPdfa: return "pdf_to_pdfa"
        case .repairPdf: return "repair_pdf"
        case .sanitizePdf: return "sanitize_pdf"
        case .sign: return "sign"
        case .formFill: return "form_fill"
        case .addText: return "add_text"
        case .createPdf: return "create_pdf"
        case .ocr: return "ocr"
        case .pageNumbers: return "page_numbers"
        case .watermark: return "watermark"
        case .removeBlankPages: return "remove_blank_pages"
        case .flattenPdf: return "flatten_pdf"
        case .invertColors: return "invert_colors"
        case .pdfPermissions: return "pdf_permissions"
        case .redactPdf: return "redact_pdf"
        case .compressPdf: return "compress_pdf"
        case .comparePdf: return "compare_pdf"
        case .rotatePdf: return "rotate_pdf"
        case .importPdf: return "import_pdf"
        case .openSignedDocument: return "open_signed_document"
        case .removeBackground: return "remove_background"
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

