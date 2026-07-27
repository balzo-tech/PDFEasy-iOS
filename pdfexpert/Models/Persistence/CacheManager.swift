//
//  CacheManager.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 22/03/23.
//

import Foundation

protocol CacheManager {
    var onboardingShown: Bool { get set }
    var preReviewShown: Bool { get set }
    // Whether the user has accepted the one-time online-conversion privacy
    // disclosure (their PDF is uploaded to the Stirling conversion service).
    var pdfConvertPrivacyAccepted: Bool { get set }
}
