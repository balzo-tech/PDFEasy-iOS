//
//  ProjectInfo.swift
//  FastCheckIn
//
//  Created by Leonardo Passeri on 03/07/23.
//

import Foundation

class ProjectInfo {

    private enum ProjectInfoKey: String, CaseIterable {

        case openAiApiKey = "OPENAI_API_KEY"
    }

    // SECURITY NOTE: This key is embedded in the client and is therefore extractable
    // by a determined attacker (e.g. inspecting the binary or proxying traffic).
    // The accepted mitigation for a future iteration is a thin server-side proxy that
    // holds the real key and enforces quotas. For now the trade-off is accepted, the
    // same way the previous CHAT_PDF_API_KEY was handled.
    // When the key is missing from the plist we deliberately default to an empty string
    // (instead of asserting) so that builds without the git-ignored ProjectInfo.plist
    // still compile and run; the chat feature then fails gracefully with a clear error.
    static var openAiApiKey: String { Self.getOptionalValue(forKey: .openAiApiKey) ?? "" }

    static func validate() {
        ProjectInfoKey.allCases.forEach { key in
            switch key {
            case .openAiApiKey: _ = Self.getOptionalValue(forKey: key) as String?
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
