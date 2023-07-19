//
//  ProjectInfo.swift
//  FastCheckIn
//
//  Created by Leonardo Passeri on 03/07/23.
//

import Foundation

class ProjectInfo {
    
    private enum ProjectInfoKey: String, CaseIterable {
        
        case chatPdfApiKey = "CHAT_PDF_API_KEY"
    }
    
    static var chatPdfApiKey: String { Self.getValue(forKey: .chatPdfApiKey, defaultValue: "") }
    
    static func validate() {
        ProjectInfoKey.allCases.forEach { key in
            switch key {
            case .chatPdfApiKey: _ = Self.getValue(forKey: key, defaultValue: "")
            }
        }
    }
    
    static private var projectInfoDictionary: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "ProjectInfo", withExtension: "plist") else {
            assertionFailure("Couldn't find ProjectInfo.plist")
            return [:]
        }
        guard let data = try? Data(contentsOf: url) else {
            assertionFailure("Couldn't open ProjectInfo.plist")
            return [:]
        }
        guard let studyConfig = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            assertionFailure("ProjectInfo.plist is not a dictionary of [String: Any]")
            return [:]
        }
        return studyConfig
    }()
    
    static private func getValue<T>(forKey key: ProjectInfoKey, defaultValue: T) -> T {
        guard let object = Self.projectInfoDictionary[key.rawValue], let value = object as? T  else {
            assertionFailure("Couldn't find \(key.rawValue) in ProjectInfo")
            return defaultValue
        }
        return value
    }
    
    static private func getOptionalValue<T>(forKey key: ProjectInfoKey) -> T? {
        guard let object = Self.projectInfoDictionary[key.rawValue], let value = object as? T  else {
            return nil
        }
        return value
    }
}
