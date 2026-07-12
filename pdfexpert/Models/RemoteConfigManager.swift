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
    let subcriptionViewType: SubscriptionViewType
    let chatGptModel: String
    let chatGptMaxTokens: Int
    let chatMaxMessagesPerMonth: Int

    init(remoteConfig: RemoteConfig) {
        let subscriptionViewTypeValue = remoteConfig.configValue(forKey: RemoteConfigKey.subcriptionViewType.rawValue).stringValue
        self.subcriptionViewType = SubscriptionViewType.getSubscriptionViewType(forRemoteConfigValue: subscriptionViewTypeValue)

        let chatGptModelValue = remoteConfig.configValue(forKey: RemoteConfigKey.chatGptModel.rawValue).stringValue ?? ""
        self.chatGptModel = chatGptModelValue.isEmpty ? K.ChatPdf.DefaultChatGptModel : chatGptModelValue

        let chatGptMaxTokensValue = remoteConfig.configValue(forKey: RemoteConfigKey.chatGptMaxTokens.rawValue).numberValue.intValue
        self.chatGptMaxTokens = chatGptMaxTokensValue > 0 ? chatGptMaxTokensValue : K.ChatPdf.DefaultChatGptMaxTokens

        let chatMaxMessagesPerMonthValue = remoteConfig.configValue(forKey: RemoteConfigKey.chatMaxMessagesPerMonth.rawValue).numberValue.intValue
        self.chatMaxMessagesPerMonth = chatMaxMessagesPerMonthValue > 0 ? chatMaxMessagesPerMonthValue : K.ChatPdf.DefaultChatMaxMessagesPerMonth
    }

    /// Memberwise initializer used by non-Firebase call sites (e.g. unit tests / previews)
    /// that need a `RemoteConfigData` without spinning up `RemoteConfig`.
    init(subcriptionViewType: SubscriptionViewType = K.MonetizationK.defaultSubscriptionViewType,
         chatGptModel: String = K.ChatPdf.DefaultChatGptModel,
         chatGptMaxTokens: Int = K.ChatPdf.DefaultChatGptMaxTokens,
         chatMaxMessagesPerMonth: Int = K.ChatPdf.DefaultChatMaxMessagesPerMonth) {
        self.subcriptionViewType = subcriptionViewType
        self.chatGptModel = chatGptModel
        self.chatGptMaxTokens = chatGptMaxTokens
        self.chatMaxMessagesPerMonth = chatMaxMessagesPerMonth
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
    
    private func createFetchConfigRequest() -> AnyPublisher<RemoteConfigData, Never> {
        return AnyPublisher<RemoteConfigData, Never>.create { subscriber in
            let notifyRemoteConfig = {
                self.sharedFetchConfigRequest = nil
                let remoteConfigData = RemoteConfigData(remoteConfig: self.remoteConfig)
                self.remoteConfigData.send(remoteConfigData)
                subscriber.send(remoteConfigData)
            }
            self.remoteConfig
                .fetch(withExpirationDuration: self.remoteConfigExpirationDuration,
                       completionHandler: { (status, error) in
                        if status == .success {
                            print("RemoteConfigManager - Config fetched!")
                            self.remoteConfig.activate(completion: { (changed, error) in
                                if let error = error {
                                    print("RemoteConfigManager - Config not activated. Error: '\(error.localizedDescription)'")
                                } else if changed {
                                    print("RemoteConfigManager - Config activated with changes")
                                } else {
                                    print("RemoteConfigManager - Config activated without changes")
                                }
                                // Must run this on main thread (this completion block runs on a different thread... how cute...)
                                DispatchQueue.main.async {
                                    notifyRemoteConfig()
                                }
                            })
                        } else {
                            print("RemoteConfigManager - Config not fetched. Error: '\(error?.localizedDescription ?? "")'")
                            DispatchQueue.main.async {
                                notifyRemoteConfig()
                            }
                        }
                })
            return AnyCancellable {}
        }.share().eraseToAnyPublisher()
    }
}

fileprivate enum RemoteConfigKey : String, CaseIterable {
    case subcriptionViewType = "subscription_view_type"
    case chatGptModel = "chat_gpt_model"
    case chatGptMaxTokens = "chat_gpt_max_tokens"
    case chatMaxMessagesPerMonth = "chat_max_messages_per_month"
}

fileprivate extension RemoteConfig {

    static var defaults: [String: NSObject] {
        var result: [String: NSObject] = [:]
        RemoteConfigKey.allCases.forEach { (key) in
            switch key {
            case .subcriptionViewType:
                result[key.rawValue] = NSString(string: K.MonetizationK.defaultSubscriptionViewType.remoteConfigValue)
            case .chatGptModel:
                result[key.rawValue] = NSString(string: K.ChatPdf.DefaultChatGptModel)
            case .chatGptMaxTokens:
                result[key.rawValue] = NSNumber(value: K.ChatPdf.DefaultChatGptMaxTokens)
            case .chatMaxMessagesPerMonth:
                result[key.rawValue] = NSNumber(value: K.ChatPdf.DefaultChatMaxMessagesPerMonth)
            }
        }
        return result
    }
}

fileprivate extension SubscriptionViewType {
    var remoteConfigValue: String {
        switch self {
        case .pairs: return "pairs"
        case .verticalHighlightLongPeriod: return "vertical"
        case .verticalHighlightShortPeriod: return "vertical_highlight_short_period"
        case .picker: return "picker"
        }
    }
    
    static func getSubscriptionViewType(forRemoteConfigValue remoteConfigValue: String?) -> Self {
        for type in Self.allCases {
            if type.remoteConfigValue == remoteConfigValue {
                return type
            }
        }
        return K.MonetizationK.defaultSubscriptionViewType
    }
}
