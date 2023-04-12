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

struct K {
    struct Test {
        static let UseMockDB = false
        static let NumberOfPdfs = 5
        
        static var DebugPdf: Pdf? {
            GetDebugPdf(context: Container.shared.persistence().container.viewContext)
        }
        
        static func GetDebugPdf(context: NSManagedObjectContext) -> Pdf? {
            let testFileUrl = Bundle.main.url(forResource: "test", withExtension: "pdf")
            guard let testFileUrl = testFileUrl,
                  (try? testFileUrl.checkResourceIsReachable()) ?? false,
                  let testFileData = try? Data(contentsOf: testFileUrl) else { return nil }
            return Pdf(context: context, pdfData: testFileData)
        }
        
        static var DebugPdfEditable: PdfEditable? {
            let testFileUrl = Bundle.main.url(forResource: "test", withExtension: "pdf")
            guard let testFileUrl = testFileUrl,
                  (try? testFileUrl.checkResourceIsReachable()) ?? false,
                  let testFileData = try? Data(contentsOf: testFileUrl) else { return nil }
            guard let testPdfDocument = PDFDocument(data: testFileData) else { return nil }
            return PdfEditable(pdfDocument: testPdfDocument)
        }
    }
    
    struct Misc {
        static let PrivacyPolicyUrlString = "https://www.balzo.eu/privacy-policy"
        static let TermsAndConditionsUrlString = "https://balzo.eu/terms-and-conditions/"
        
        static let DocFileTypes: [UTType] = [UTType("com.microsoft.word.doc")!]
        static let ThumbnailSize: CGSize = CGSize(width: 256, height: 256)
        static let ThumbnailEditSize: CGSize = CGSize(width: 80, height: 80)
    }
}
