//
//  SharedLocalizedError.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 07/03/23.
//

import Foundation

enum SharedLocalizedError: LocalizedError {
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return String(localized: "Internal Error. Please try again later")
        }
    }
}

enum SharedUnderlyingError: LocalizedError, UnderlyingError {
    case unknownError
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return String(localized: "Internal Error. Please try again later")
        case .underlyingError(let errorMessage): return errorMessage
        }
    }
}

enum PdfError: LocalizedError, UnderlyingError {
    case unknownError
    case urlToPdfConversionError
    case underlyingError(errorDescription: String)
    case wrongPassword
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError:
            return String(localized: "Internal Error. Please try again later")
        // A file that will not open is not an internal error: it is a truncated
        // download, a damaged attachment, something with a .pdf on the end that
        // never was one. Sharing the wording with `unknownError` asked the user
        // to try again at something that will never work, and blamed the app
        // for the file.
        case .urlToPdfConversionError:
            return String(localized: "This file could not be opened. It may be damaged, or not a PDF.")
        case .underlyingError(let errorMessage): return errorMessage
        case .wrongPassword: return String(localized: "Wrong Password")
        }
    }
}

enum AddPasswordError: LocalizedError {
    case unknownError
    case pdfHasPassword
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return String(localized: "Internal Error. Please try again later")
        case .pdfHasPassword: return String(localized: "Your pdf is already protected")
        }
    }
}

enum RemovePasswordError: LocalizedError {
    case unknownError
    case pdfNoPassword
    
    var errorDescription: String? {
        switch self {
        case .unknownError: return String(localized: "Internal Error. Please try again later")
        case .pdfNoPassword: return String(localized: "Your pdf is already unlocked")
        }
    }
}

enum PdfSplitError: LocalizedError, UnderlyingError {
    case unknownError
    case pdfNoPage
    case pdfSinglePage
    case incompatibleRange
    case underlyingError(errorDescription: String)
    
    static func getUnknownError() -> Self { Self.unknownError }
    
    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }
    
    var errorDescription: String? {
        switch self {
        case .unknownError, .incompatibleRange: return String(localized: "Internal Error. Please try again later")
        case .pdfNoPage: return String(localized: "Your pdf has no pages.")
        case .pdfSinglePage: return String(localized: "Your pdf has only one page, so you cannot split it into multiple pdfs.")
        case .underlyingError(let errorMessage): return errorMessage
        }
    }
}

enum PdfExtractError: LocalizedError, UnderlyingError {
    case unknownError
    case pdfNoPage
    case pdfSinglePage
    case incompatibleRange
    case underlyingError(errorDescription: String)

    static func getUnknownError() -> Self { Self.unknownError }

    static func getUnderlyingError(errorDescription: String) -> Self {
        return .underlyingError(errorDescription: errorDescription)
    }

    var errorDescription: String? {
        switch self {
        case .unknownError, .incompatibleRange: return String(localized: "Internal Error. Please try again later")
        case .pdfNoPage: return String(localized: "Your pdf has no pages.")
        case .pdfSinglePage: return String(localized: "Your pdf has only one page, so you cannot extract pages from it.")
        case .underlyingError(let errorMessage): return errorMessage
        }
    }
}

enum PdfPermissionsError: LocalizedError, Equatable {
    /// The permission flags are only enforceable when an owner password is set, so an
    /// empty one is rejected instead of writing a file that promises nothing.
    case missingOwnerPassword
    case encodingFailed
    case unknownError

    var errorDescription: String? {
        switch self {
        case .missingOwnerPassword:
            return String(localized: "Enter an owner password: without it the permissions cannot be enforced.")
        case .encodingFailed:
            return String(localized: "The permissions could not be applied to this PDF.")
        case .unknownError:
            return String(localized: "Internal Error. Please try again later")
        }
    }
}

enum PdfExportError: LocalizedError, Equatable {
    case noTextFound
    case noImagesFound
    case unknownError

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return String(localized: "This PDF has no extractable text. Try \"Make Searchable (OCR)\" first, then export again.")
        case .noImagesFound:
            return String(localized: "This PDF contains no embedded images to export.")
        case .unknownError:
            return String(localized: "Internal Error. Please try again later")
        }
    }
}
