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
    
    init(remoteConfig: RemoteConfig) {
        let subscriptionViewTypeValue = remoteConfig.configValue(forKey: RemoteConfigKey.subcriptionViewType.rawValue).stringValue
        self.subcriptionViewType = SubscriptionViewType.getSubscriptionViewType(forRemoteConfigValue: subscriptionViewTypeValue)
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
}

fileprivate extension RemoteConfig {
    
    static var defaults: [String: NSObject] {
        var result: [String: NSObject] = [:]
        RemoteConfigKey.allCases.forEach { (key) in
            switch key {
            case .subcriptionViewType:
                result[key.rawValue] = NSString(string: K.MonetizationK.defaultSubscriptionViewType.remoteConfigValue)
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
