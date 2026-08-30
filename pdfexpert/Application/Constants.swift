//
//  Constants.swift
//  PdfExpert
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

        // MARK: - The document that goes on the App Store page

        /// A lease agreement, one per language the app speaks.
        ///
        /// `test.pdf` is Lorem ipsum, which is fine for exercising layouts and
        /// wrong for the store: the signature, the editor and the password
        /// screens are all photographed over a document, and fake Latin in a
        /// screenshot reads as a mock-up of an app rather than an app. This one
        /// is a contract with real clauses and real figures, so the picture
        /// shows the thing the app is for.
        ///
        /// The same file is the one to open in ChatPDF for the sixth shot — the
        /// answer quotes the deposit and the notice period straight out of it.
        static var DebugContractName: String {
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            return ["it", "es", "de", "fr"].contains(code) ? "contract-\(code)" : "contract-en"
        }

        static var DebugContractDocument: PDFDocument? {
            guard let url = Bundle.main.url(forResource: DebugContractName, withExtension: "pdf"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return PDFDocument(data: data)
        }

        static var DebugContractPdf: Pdf? {
            guard let document = DebugContractDocument else { return nil }
            return Pdf(pdfDocument: document)
        }

        /// What the contract is called in the archive, in the language it is
        /// written in. It ends up in the editor's title bar, in the picture.
        static var DebugContractFilename: String {
            switch Locale.current.language.languageCode?.identifier {
            case "it": return "Contratto di locazione"
            case "es": return "Contrato de arrendamiento"
            case "de": return "Mietvertrag"
            case "fr": return "Contrat de location"
            default:   return "Rental agreement"
            }
        }

        /// The four documents that fill the archive behind the contract.
        ///
        /// They are only ever read as a list of names in the picture, but a list
        /// of English names under an Italian sidebar is exactly the detail that
        /// makes a store page look machine-made. Same reasoning as
        /// `DebugContractFilename`, and the same reason they are not in the
        /// string catalog: they are stage props, not interface.
        static var DebugSeedFilenames: [String] {
            switch Locale.current.language.languageCode?.identifier {
            case "it": return ["Fattura 2026-07", "Ricevuta scansionata",
                               "Scansione passaporto", "Verbale riunione"]
            case "es": return ["Factura 2026-07", "Recibo escaneado",
                               "Escaneo del pasaporte", "Acta de reunión"]
            case "de": return ["Rechnung 2026-07", "Gescannter Beleg",
                               "Passscan", "Besprechungsnotizen"]
            case "fr": return ["Facture 2026-07", "Reçu scanné",
                               "Scan du passeport", "Notes de réunion"]
            default:   return ["Invoice 2026-07", "Scanned receipt",
                               "Passport scan", "Meeting notes"]
            }
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

    struct Proxy {
        /// Where the Cloudflare Worker answers. Overridable from remote config so
        /// the host can be moved without shipping a build, which matters for the
        /// one piece of infrastructure every online feature now goes through.
        /// Empty means "not deployed yet": the online features stay hidden rather
        /// than failing against a URL nobody owns.
        static let DefaultBaseUrl = ""
    }

    struct Stirling {
        // On by default, so the online tools ship listed rather than waiting for
        // someone to remember a Firebase flag. It is not the whole switch: the
        // request needs somewhere to go, and that is `K.Proxy.DefaultBaseUrl`
        // overridden by `proxy_base_url`. While that is empty `isAvailable`
        // stays false and the online tools stay out of the catalog. The remote
        // flag remains the kill switch if the service goes down.
        //
        // Where Stirling itself answers is no longer the app's business: the
        // worker holds that address along with the key.
        static let DefaultEnabled = true

        // Conversions can be long-running; give the request a generous timeout so it
        // is not cut off by Alamofire's default 60s.
        static let RequestTimeout: TimeInterval = 120.0
    }

    struct Review {
        static let MinimumRateForNativePopup: Int = 5
        static let FeedbackMaxCharacters: Int = 100
    }

    struct DocumentRender {
        // WebKit loads a local document quickly; a long timeout here would only make a
        // hopeless conversion feel broken before the online fallback is offered.
        static let FileTimeout: TimeInterval = 30.0
        // Remote pages have to cross the network, so they get more room.
        static let WebPageTimeout: TimeInterval = 45.0
    }
    
    struct Misc {
        static let AppTitle = "PDF Pro"
        
        static let PrivacyPolicyUrlString = "https://www.balzo.eu/privacy-policy"
        // The path is `terms-conditions`, without the `and`, and the host wants
        // its `www`: the old string answered 404, from Settings and from the
        // paywall both.
        static let TermsAndConditionsUrlString = "https://www.balzo.eu/terms-conditions"
        
        /// Word's two formats, which are two unrelated types: `.docx` does NOT
        /// conform to `com.microsoft.word.doc` — that one is Word 97 — so listing
        /// only the old one greys out every `.docx` in the picker. Spreadsheets and
        /// presentations need no such pair: `.xlsx` and `.pptx` do conform to
        /// `public.spreadsheet` and `public.presentation`.
        static let WordFileTypes: [UTType] = {
            [
                UTType("com.microsoft.word.doc"),
                UTType("org.openxmlformats.wordprocessingml.document")
            ].compactMap { $0 }
        }()

        /// The CMS envelope `.p7m` files come wrapped in. iOS declares no type for
        /// them, so the app imports its own (see `UTImportedTypeDeclarations` in
        /// Info.plist) and the picker has to name it explicitly — a document type
        /// the system does not know is greyed out in Files.
        static let SignedContainerFileTypes: [UTType] = {
            [UTType("public.pkcs7-mime")].compactMap { $0 }
        }()

        static let ImportFileTypesForAddPage: [UTType] = {
            [
                UTType.image,
                UTType.pdf,
                .presentation,
                .spreadsheet,
                UTType("com.apple.iwork.pages.sffpages")
            ].compactMap { $0 } + Self.WordFileTypes
        }()
        static let ImportFileTypesForMerge: [UTType] = { [UTType.pdf].compactMap { $0 } }()
        static let ImportFileTypesForSplit: [UTType] = { [UTType.pdf].compactMap { $0 } }()
        static let ImportFileTypesForExtract: [UTType] = { [UTType.pdf].compactMap { $0 } }()
        static let ImportFileTypesForRead: [UTType] = { [UTType.pdf].compactMap { $0 } }()
        // Markdown has no universal system type on every OS version, so plain text is
        // accepted alongside it (a .md file is plain text anyway).
        static let ImportFileTypesForMarkdown: [UTType] = {
            [UTType("net.daringfireball.markdown"), UTType.plainText].compactMap { $0 }
        }()
        
        static let ThumbnailSize: CGSize = CGSize(width: 256, height: 256)
        static let ThumbnailEditSize: CGSize = CGSize(width: 80, height: 80)
        static let PdfPageSize: CGSize = CGSize(width: 595, height: 842)
        static let PdfPageDefaultMargin: CGFloat = 0
        static let DefaultAnnotationTextFontSize: CGFloat = 10.0
        static let DefaultAnnotationTextFontName: String = "Arial"
        // Both of these are now the only value either option ever takes: the
        // pickers that set them are gone (compressing is the Compress tool's job),
        // but the attributes stay on the Core Data entity — the store is
        // CloudKit-backed and dropping a column is not worth a migration.
        static let PdfDefaultMarginsOption: MarginsOption = .noMargins
        static let PdfDefaultCompression: CompressionOption = .noCompression
        static let PdfReaderDefaultFontScale: CGFloat = 1.5
        static let SignatureDrawScaleFactor: CGFloat = 3.0

        // MARK: Scanner
        //
        /// JPEG quality for a scanned page. High enough that small print stays
        /// legible after the perspective correction has resampled it, low enough
        /// that a twenty-page scan is still mailable.
        static let ScanJpegQuality: CGFloat = 0.8
        /// Longest side of a page kept in the finished PDF. Well above what a
        /// 300-dpi A4 scan needs (2480 px), so text stays sharp, while capping
        /// the 48-megapixel captures recent phones produce.
        static let ScanPageMaxDimension: CGFloat = 2600
        /// Longest side of the page previews shown during review.
        static let ScanPreviewMaxDimension: CGFloat = 1400
        /// Longest side of the thumbnails in the capture strip.
        static let ScanThumbnailMaxDimension: CGFloat = 240
        /// How still the detected page has to be, in normalized units, for the
        /// automatic shutter to consider the phone steady.
        static let ScanAutoShutterTolerance: CGFloat = 0.022
        /// How many consecutive steady detections trigger the automatic shutter.
        /// At roughly ten detections a second this is a beat under a second —
        /// long enough not to fire while the user is still framing.
        static let ScanAutoShutterSteadyFrames: Int = 8
    }
}

extension ImportFileOption: FilePickerTypeProvider {
     
    var fileTypes: [UTType] {
        switch self {
        case .image: return [UTType.image]
        case .word: return K.Misc.WordFileTypes
        case .excel: return [.spreadsheet]
        case .powerpoint: return [.presentation]
        case .pdf: return [UTType.pdf] + K.Misc.SignedContainerFileTypes
        case .allDocs: return [
            UTType.pdf,
            .presentation,
            .spreadsheet,
            UTType("com.apple.iwork.pages.sffpages")
        ].compactMap { $0 } + K.Misc.WordFileTypes + K.Misc.SignedContainerFileTypes
        }
    }
 }
