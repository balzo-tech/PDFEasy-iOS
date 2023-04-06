//
//  Constants.swift
//  ChatAI
//
//  Created by Leonardo Passeri on 23/02/23.
//

import Foundation
import UniformTypeIdentifiers

struct K {
    struct Test {
        static let UseMockDB = true
    }
    
    struct Misc {
        static let PrivacyPolicyUrlString = "https://www.balzo.eu/privacy-policy"
        static let TermsAndConditionsUrlString = "https://balzo.eu/terms-and-conditions/"
        
        static let DocFileTypes: [UTType] = [UTType("com.microsoft.word.doc")!]
        static let ThumbnailSize: CGSize = CGSize(width: 256, height: 256)
    }
}
