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
    case vertical
}

struct K {
    struct Test {
        static let UseMockDB = false
        static let NumberOfPdfs = 5
        
        static var DebugPdf: Pdf? {
            GetDebugPdf(context: Container.shared.persistence().container.viewContext, password: nil)
        }
        
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
        
        static func GetDebugPdf(context: NSManagedObjectContext, password: String?) -> Pdf? {
            guard let testFileData = DebugPdfDocumentData else { return nil }
            return Pdf(context: context, pdfData: testFileData, password: password)
        }
        
        static var DebugPdfEditable: PdfEditable? {
            guard let testPdfDocument = DebugPdfDocument else { return nil }
            return PdfEditable(pdfDocument: testPdfDocument)
        }
    }
    
    struct MonetizationK {
        static let defaultSubscriptionViewType: SubscriptionViewType = .vertical
    }
    
    struct RemoteConfigK {
        static let DebugRemoteConfigExpirationDuration: TimeInterval = 30.0
        static let DefaultRemoteConfigExpirationDuration: TimeInterval = 60.0 * 60.0
    }
    
    struct Misc {
        static let PrivacyPolicyUrlString = "https://www.balzo.eu/privacy-policy"
        static let TermsAndConditionsUrlString = "https://balzo.eu/terms-and-conditions/"
        
        static let DocFileTypes: [UTType] = [UTType("com.microsoft.word.doc")!]
        static let ThumbnailSize: CGSize = CGSize(width: 256, height: 256)
        static let ThumbnailEditSize: CGSize = CGSize(width: 80, height: 80)
        static let PdfMarginsColor: UIColor = .white
        static let PdfDefaultMarginOption: MarginsOption = .noMargins
        static let PdfDefaultCompression: CGFloat = 0.0
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
