//
//  OnboardingOption+View.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 04/04/23.
//

import Foundation

extension OnboardingOptionRole: OnboardingOptionView {
    var id: String { self.rawValue }
    
    var displayText: String {
        switch self {
        case .teaching: return "Education"
        case .design: return "Designer or Project Manager"
        case .legal: return "Legal"
        case .selling: return "Business and Sales Manager"
        case .it: return "IT Specialist"
        case .student: return "Student"
        case .healthcare: return "Healthcare"
        case .other: return "Other..."
        }
    }
    
    var displayImageName: String {
        switch self {
        case .teaching: return "onboarding_teaching"
        case .design: return "onboarding_design"
        case .legal: return "onboarding_legal"
        case .selling: return "onboarding_selling"
        case .it: return "onboarding_it"
        case .student: return "onboarding_student"
        case .healthcare: return "onboarding_healthcare"
        case .other: return "onboarding_other"
        }
    }
}

extension OnboardingOptionTool: OnboardingOptionView {
    var id: String { self.rawValue }
    
    var displayText: String {
        switch self {
        case .edit: return "Edit text"
        case .notes: return "Mark and Notes"
        case .compression: return "Reduce file size"
        case .merge: return "Merge PDF"
        case .ocr: return "OCR"
        case .sign: return "Fill and Sign"
        case .manage: return "Manage pages"
        case .convert: return "Convert PDF in Word, Excel, PPT"
        }
    }
    
    var displayImageName: String {
        switch self {
        case .edit: return "onboarding_edit"
        case .notes: return "onboarding_notes"
        case .compression: return "onboarding_compression"
        case .merge: return "onboarding_merge"
        case .ocr: return "onboarding_ocr"
        case .sign: return "onboarding_sign"
        case .manage: return "onboarding_manage"
        case .convert: return "onboarding_convert"
        }
    }
}

extension OnboardingOptionMac: OnboardingOptionView {
    var id: String { self.rawValue }
    
    var displayText: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }
    
    var displayImageName: String {
        switch self {
        case .yes: return "onboarding_yes"
        case .no: return "onboarding_no"
        }
    }
}

extension OnboardingQuestion: OnboardingQuestionView {
    var title: String {
        switch self {
        case .role: return "What describes you best?"
        case .tool: return "What tools will you use?"
        case .mac: return "Do you have a Mac?"
        }
    }
    var subtitle: String {
        switch self {
        case .role: return "The tools that make you brilliant in what you do"
        case .tool: return "Select what you love most "
        case .mac: return "Please select yes or not"
        }
    }
    var options: [any OnboardingOptionView] {
        switch self {
        case .role: return OnboardingOptionRole.allCases
        case .tool: return OnboardingOptionTool.allCases
        case .mac: return OnboardingOptionMac.allCases
        }
    }
}
