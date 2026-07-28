//
//  RemoteConfigImpl.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 13/04/23.
//

import Foundation
import Factory
import FirebaseRemoteConfig
import Combine
import CombineExt

struct RemoteConfigData {
    let proxyBaseUrl: String
    let chatGptModel: String
    let chatGptMaxTokens: Int
    let chatMaxMessagesPerMonth: Int
    let stirlingApiEnabled: Bool
    let stirlingApiBaseUrl: String

    init(remoteConfig: RemoteConfig) {
        let proxyBaseUrlValue = remoteConfig.configValue(forKey: RemoteConfigKey.proxyBaseUrl.rawValue).stringValue ?? ""
        self.proxyBaseUrl = proxyBaseUrlValue.isEmpty ? K.Proxy.DefaultBaseUrl : proxyBaseUrlValue

        let chatGptModelValue = remoteConfig.configValue(forKey: RemoteConfigKey.chatGptModel.rawValue).stringValue ?? ""
        self.chatGptModel = chatGptModelValue.isEmpty ? K.ChatPdf.DefaultChatGptModel : chatGptModelValue

        let chatGptMaxTokensValue = remoteConfig.configValue(forKey: RemoteConfigKey.chatGptMaxTokens.rawValue).numberValue.intValue
        self.chatGptMaxTokens = chatGptMaxTokensValue > 0 ? chatGptMaxTokensValue : K.ChatPdf.DefaultChatGptMaxTokens

        let chatMaxMessagesPerMonthValue = remoteConfig.configValue(forKey: RemoteConfigKey.chatMaxMessagesPerMonth.rawValue).numberValue.intValue
        self.chatMaxMessagesPerMonth = chatMaxMessagesPerMonthValue > 0 ? chatMaxMessagesPerMonthValue : K.ChatPdf.DefaultChatMaxMessagesPerMonth

        self.stirlingApiEnabled = remoteConfig.configValue(forKey: RemoteConfigKey.stirlingApiEnabled.rawValue).boolValue

        let stirlingApiBaseUrlValue = remoteConfig.configValue(forKey: RemoteConfigKey.stirlingApiBaseUrl.rawValue).stringValue ?? ""
        self.stirlingApiBaseUrl = stirlingApiBaseUrlValue.isEmpty ? K.Stirling.DefaultBaseUrl : stirlingApiBaseUrlValue
    }

    /// Memberwise initializer used by non-Firebase call sites (e.g. unit tests / previews)
    /// that need a `RemoteConfigData` without spinning up `RemoteConfig`.
    init(proxyBaseUrl: String = K.Proxy.DefaultBaseUrl,
         chatGptModel: String = K.ChatPdf.DefaultChatGptModel,
         chatGptMaxTokens: Int = K.ChatPdf.DefaultChatGptMaxTokens,
         chatMaxMessagesPerMonth: Int = K.ChatPdf.DefaultChatMaxMessagesPerMonth,
         stirlingApiEnabled: Bool = K.Stirling.DefaultEnabled,
         stirlingApiBaseUrl: String = K.Stirling.DefaultBaseUrl) {
        self.proxyBaseUrl = proxyBaseUrl
        self.chatGptModel = chatGptModel
        self.chatGptMaxTokens = chatGptMaxTokens
        self.chatMaxMessagesPerMonth = chatMaxMessagesPerMonth
        self.stirlingApiEnabled = stirlingApiEnabled
        self.stirlingApiBaseUrl = stirlingApiBaseUrl
    }
}

extension Container {
    var configService: Factory<ConfigService> {
        self { RemoteConfigManager() }.singleton
    }
}

class RemoteConfigManager : ConfigService {
    
    lazy var remoteConfigData: CurrentValueSubject<RemoteConfigData, Never> = CurrentValueSubject<RemoteConfigData, Never>(RemoteConfigData(remoteConfig: self.remoteConfig))
    
    private var remoteConfigExpirationDuration: TimeInterval {
        return self.isTestUser
            ? K.RemoteConfigK.DebugRemoteConfigExpirationDuration
            : K.RemoteConfigK.DefaultRemoteConfigExpirationDuration
    }
    
    private var sharedFetchConfigRequest: AnyPublisher<RemoteConfigData, Never>?
    private let remoteConfig: RemoteConfig
    private var cancelBag = Set<AnyCancellable>()
    private var isTestUser: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    init() {
        self.remoteConfig = RemoteConfig.remoteConfig()
        self.remoteConfig.configSettings = RemoteConfigSettings()
        self.remoteConfig.setDefaults(RemoteConfig.defaults)
    }
    
    // MARK: - ConfigService
    
    func onApplicationDidBecomeActive() {
        self.fetchConfig().sink(receiveValue: { _ in }).store(in: &self.cancelBag)
    }
    
    // MARK: Private methods
    
    private func fetchConfig() -> AnyPublisher<RemoteConfigData, Never> {
        print("RemoteConfigManager - fetchConfig started")
        let sharedFetchConfigRequest: AnyPublisher<RemoteConfigData, Never> = {
            if let sharedFetchConfigRequest = self.sharedFetchConfigRequest {
                print("RemoteConfigManager - returned cached instance")
                return sharedFetchConfigRequest
            } else {
                print("RemoteConfigManager - returned new instance")
                return self.createFetchConfigRequest()
            }
        }()
        self.sharedFetchConfigRequest = sharedFetchConfigRequest
        return sharedFetchConfigRequest
    }
    
    /// Fetch then activate, as one sequence rather than a callback inside a callback.
    ///
    /// Firebase hands both results back on some queue of its own, which is why this
    /// used to hop to the main thread by hand in two places; `@MainActor` on the task
    /// says it once. Whatever happens — fetched, throttled, offline — the subscriber
    /// is told, because callers wait on this before deciding what the app can do.
    private func createFetchConfigRequest() -> AnyPublisher<RemoteConfigData, Never> {
        return AnyPublisher<RemoteConfigData, Never>.create { subscriber in
            let task = Task { @MainActor in
                do {
                    let status = try await self.remoteConfig
                        .fetch(withExpirationDuration: self.remoteConfigExpirationDuration)
                    if status == .success {
                        print("RemoteConfigManager - Config fetched!")
                        let changed = try await self.remoteConfig.activate()
                        print("RemoteConfigManager - Config activated \(changed ? "with" : "without") changes")
                    } else {
                        print("RemoteConfigManager - Config not fetched. Status: '\(status.rawValue)'")
                    }
                } catch {
                    print("RemoteConfigManager - Config not fetched or activated. Error: '\(error.localizedDescription)'")
                }
                self.sharedFetchConfigRequest = nil
                let remoteConfigData = RemoteConfigData(remoteConfig: self.remoteConfig)
                self.remoteConfigData.send(remoteConfigData)
                subscriber.send(remoteConfigData)
            }
            // The old cancellable was empty, so cancelling the publisher left the
            // fetch running and still writing to `remoteConfigData` afterwards.
            return AnyCancellable { task.cancel() }
        }.share().eraseToAnyPublisher()
    }
}

fileprivate enum RemoteConfigKey : String, CaseIterable {
    case proxyBaseUrl = "proxy_base_url"
    case chatGptModel = "chat_gpt_model"
    case chatGptMaxTokens = "chat_gpt_max_tokens"
    case chatMaxMessagesPerMonth = "chat_max_messages_per_month"
    case stirlingApiEnabled = "stirling_api_enabled"
    case stirlingApiBaseUrl = "stirling_api_base_url"
}

fileprivate extension RemoteConfig {

    static var defaults: [String: NSObject] {
        var result: [String: NSObject] = [:]
        RemoteConfigKey.allCases.forEach { (key) in
            switch key {
            case .proxyBaseUrl:
                result[key.rawValue] = NSString(string: K.Proxy.DefaultBaseUrl)
            case .chatGptModel:
                result[key.rawValue] = NSString(string: K.ChatPdf.DefaultChatGptModel)
            case .chatGptMaxTokens:
                result[key.rawValue] = NSNumber(value: K.ChatPdf.DefaultChatGptMaxTokens)
            case .chatMaxMessagesPerMonth:
                result[key.rawValue] = NSNumber(value: K.ChatPdf.DefaultChatMaxMessagesPerMonth)
            case .stirlingApiEnabled:
                result[key.rawValue] = NSNumber(value: K.Stirling.DefaultEnabled)
            case .stirlingApiBaseUrl:
                result[key.rawValue] = NSString(string: K.Stirling.DefaultBaseUrl)
            }
        }
        return result
    }
}
