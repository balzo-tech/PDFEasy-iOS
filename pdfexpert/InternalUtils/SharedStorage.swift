//
//  SharedStorage.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 05/05/23.
//

import Foundation

class SharedStorage {
    
    enum UserDefaultsKey: String {
        case pdfDataShareExtension
    }
    
    private static let userDefaults = UserDefaults(suiteName: "group.eu.balzo.pdfexpert")
    
    static var pdfDataShareExtension: Data? {
        get { Self.userDefaults?.object(forKey: UserDefaultsKey.pdfDataShareExtension.rawValue) as? Data }
        set {
            Self.userDefaults?.set(newValue, forKey: UserDefaultsKey.pdfDataShareExtension.rawValue)
            Self.userDefaults?.synchronize()
        }
    }
}
