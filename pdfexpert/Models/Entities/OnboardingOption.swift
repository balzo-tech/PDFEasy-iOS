//
//  OnboardingOption.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/04/23.
//

import Foundation

protocol OnboardingOption {
    var trackingParameterValue: String { get }
}

enum OnboardingOptionRole: String, CaseIterable, OnboardingOption {
    case teaching
    case design
    case legal
    case selling
    case it
    case student
    case healthcare
    case other
    
    var trackingParameterValue: String { self.rawValue }
}

enum OnboardingOptionTool: String, CaseIterable, OnboardingOption {
    case edit
    case notes
    case compression
    case merge
    case ocr
    case sign
    case manage
    case convert
    
    var trackingParameterValue: String { self.rawValue }
}

enum OnboardingOptionMac: String, CaseIterable, OnboardingOption {
    case yes
    case no
    
    var trackingParameterValue: String { self.rawValue }
}
