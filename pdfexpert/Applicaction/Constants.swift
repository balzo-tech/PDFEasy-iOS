//
//  Constants.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import Foundation
import CoreData
import UniformTypeIdentifiers
import PDFKit
import Factory

enum SubscriptionViewType: CaseIterable {
    case pairs
    case verticalHighlightLongPeriod
    case verticalHighlightShortPeriod
    case picker
}

struct K {
    struct Test {
        static let UseMockDB = false
        static let NumberOfPdfs = 5
        
        static var DebugPdfDocumentUrl: URL? {
            return Bundle.main.url(forResource: "test", withExtension: "pdf")
        }
        
        static var DebugPdfDocumentData: Data? {
            guard let testFileUrl = DebugPdfDocumentUrl, (try? testFileUrl.checkResourceIsReachable()) ?? false else { return nil }
            return try? Data(contentsOf: testFileUrl)
        }
        
        static var DebugPdfDocument: PDFDocument? {
            guard let testFileDataUrl = DebugPdfDocumentData else { return nil }
            return PDFDocument(data: testFileDataUrl)
        }
        
        static func GetDebugCoreDataPdf(context: NSManagedObjectContext) -> CDPdf? {
            guard let testPdf = DebugPdf, let pdfData = testPdf.rawData else { return nil }
            let coreDataPdf = CDPdf(context: context)
            coreDataPdf.update(withPdf: testPdf, pdfData: pdfData)
            return coreDataPdf
        }
        
        static var DebugPdf: Pdf? {
            guard let testPdfDocument = DebugPdfDocument else { return nil }
            return Pdf(pdfDocument: testPdfDocument)
        }
        
        struct ChatPdf {
            static let UseMock = false
            static let NetworkStubsDelay = 1.0
            static let NetworkLogVerbose = false
        }

        struct Stirling {
            static let UseMock = false
            static let NetworkStubsDelay = 1.0
            static let NetworkLogVerbose = false
        }

        struct Review {
            // If set to true, the review flow starts every time the current logic would trigger it,
            // even if it has already been shown in the past.
            static let ShowAlways = false
        }
    }
    
    struct MonetizationK {
        static let defaultSubscriptionViewType: SubscriptionViewType = .verticalHighlightLongPeriod
    }
    
    struct RemoteConfigK {
        static let DebugRemoteConfigExpirationDuration: TimeInterval = 30.0
        static let DefaultRemoteConfigExpirationDuration: TimeInterval = 60.0 * 60.0
    }
    
    struct ChatPdf {
        // Remote-config defaults for the OpenAI-backed chat.
        static let DefaultChatGptModel: String = "gpt-4o-mini"
        static let DefaultChatGptMaxTokens: Int = 1024
        static let DefaultChatMaxMessagesPerMonth: Int = 20

        // Maximum number of characters of extracted document text sent to the model.
        // Roughly ~15k tokens for typical English text, leaving head-room for the
        // conversation and the reply within the model context window.
        static let DocumentCharacterBudget: Int = 60_000

        // How many past messages (user + assistant) of context to keep in memory and
        // replay on each request. 20 messages == the last ~10 exchanges.
        static let ConversationHistoryMessageLimit: Int = 20
    }

    struct Stirling {
        // In-app fallbacks for the Stirling-PDF remote-config values.
        static let DefaultBaseUrl = "https://api.stirling.com"
        static let DefaultEnabled = false

        // Conversions can be long-running; give the request a generous timeout so it
        // is not cut off by Alamofire's default 60s.
        static let RequestTimeout: TimeInterval = 120.0
    }

    struct Review {
        static let MinimumRateForNativePopup: Int = 5
        static let FeedbackMaxCharacters: Int = 100
    }
    
    struct Misc {
        static let AppTitle = "PDF Pro"
        
        static let PrivacyPolicyUrlString = "https://www.balzo.eu/privacy-policy"
        static let TermsAndConditionsUrlString = "https://balzo.eu/terms-and-conditions/"
        
        static let ImportFileTypesForAddPage: [UTType] = {
            [
                UTType.image,
                UTType.pdf,
                .presentation,
                .spreadsheet,
                UTType("com.microsoft.word.doc"),
                UTType("com.apple.iwork.pages.sffpages")
            ].compactMap { $0 }
        }()
        static let ImportFileTypesForMerge: [UTType] = { [UTType.pdf].compactMap { $0 } }()
        static let ImportFileTypesForSplit: [UTType] = { [UTType.pdf].compactMap { $0 } }()
        static let ImportFileTypesForExtract: [UTType] = { [UTType.pdf].compactMap { $0 } }()
        static let ImportFileTypesForRead: [UTType] = { [UTType.pdf].compactMap { $0 } }()
        
        static let ThumbnailSize: CGSize = CGSize(width: 256, height: 256)
        static let ThumbnailEditSize: CGSize = CGSize(width: 80, height: 80)
        static let PdfPageSize: CGSize = CGSize(width: 595, height: 842)
        static let PdfPageDefaultMargin: CGFloat = 0
        static let DefaultAnnotationTextFontSize: CGFloat = 10.0
        static let DefaultAnnotationTextFontName: String = "Arial"
        static let PdfMarginsColor: UIColor = .white
        static let PdfDefaultMarginsOption: MarginsOption = .noMargins
        static let PdfDefaultCompression: CompressionOption = .noCompression
        static let PdfReaderDefaultFontScale: CGFloat = 1.5
        static let SignatureDrawScaleFactor: CGFloat = 3.0
    }
}

extension MarginsOption {
    var horizontalMargin: CGFloat {
        switch self {
        case .noMargins: return 0.0
        case .mediumMargins: return 20.0
        case .heavyMargins: return 40.0
        }
    }
}

extension CompressionOption {
    var quality: CGFloat {
        switch self {
        case .noCompression: return 1.0
        case .low: return 0.66
        case .medium: return 0.33
        case .high: return 0
        }
    }
}

extension ImportFileOption: FilePickerTypeProvider {
     
    var fileTypes: [UTType] {
        switch self {
        case .image: return [UTType.image]
        case .word: return [UTType("com.microsoft.word.doc")].compactMap { $0 }
        case .excel: return [.spreadsheet]
        case .powerpoint: return [.presentation]
        case .pdf: return [UTType.pdf]
        case .allDocs: return [
            UTType.pdf,
            .presentation,
            .spreadsheet,
            UTType("com.microsoft.word.doc"),
            UTType("com.apple.iwork.pages.sffpages")
        ].compactMap { $0 }
        }
    }
 }
