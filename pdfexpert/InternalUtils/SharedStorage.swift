//
//  SharedStorage.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 05/05/23.
//

import Foundation

class SharedStorage {
    
    enum UserDefaultsKey: String {
        case pdfDataShareExtensionExistanceFlag
        case pdfDataShareExtensionPassword
    }
    
    enum FileName: String {
        case pdfDataShareExtension
    }
    
    #if STAGING
    static let schema = "pdfprostaging://"
    #else
    static let schema = "pdfpro://"
    #endif
    
    private static let appGroup = "group.eu.balzo.pdfexpert"
    private static let userDefaults = UserDefaults(suiteName: appGroup)
    
    static var cacheDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?.appending(path: "Library/Caches",
                                                                                                          directoryHint: .isDirectory)
    }
    
    static var pdfDataShareExtensionExistanceFlag: Bool {
        get { Self.userDefaults?.bool(forKey: UserDefaultsKey.pdfDataShareExtensionExistanceFlag.rawValue) ?? false }
        set {
            Self.userDefaults?.set(newValue, forKey: UserDefaultsKey.pdfDataShareExtensionExistanceFlag.rawValue)
            Self.userDefaults?.synchronize()
        }
    }
    
    static var pdfDataShareExtensionPassword: String? {
        get { Self.userDefaults?.string(forKey: UserDefaultsKey.pdfDataShareExtensionPassword.rawValue) }
        set {
            Self.userDefaults?.set(newValue, forKey: UserDefaultsKey.pdfDataShareExtensionPassword.rawValue)
            Self.userDefaults?.synchronize()
        }
    }
    
    private static var pdfDataShareExtensionFilePath: URL? {
        Self.cacheDirectory?.appending(component: FileName.pdfDataShareExtension.rawValue).appendingPathExtension(for: .pdf)
    }
    
    static var pdfDataShareExtension: Data? {
        get {
            guard let url = Self.pdfDataShareExtensionFilePath else { return nil }
            return try? Data(contentsOf: url)
        }
        set {
            guard let url = Self.pdfDataShareExtensionFilePath else { return }
            if let newValue = newValue {
                try? newValue.write(to: url)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
