//
//  OnboardingQuestion.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/04/23.
//

import Foundation

enum OnboardingQuestion: String, CaseIterable, Hashable {
    case role
    case tool
    case mac
    
    var trackingParameterKey: String { self.rawValue }
}
