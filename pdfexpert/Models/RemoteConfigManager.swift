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
    }

    /// Memberwise initializer used by non-Firebase call sites (e.g. unit tests / previews)
    /// that need a `RemoteConfigData` without spinning up `RemoteConfig`.
    init(proxyBaseUrl: String = K.Proxy.DefaultBaseUrl,
         chatGptModel: String = K.ChatPdf.DefaultChatGptModel,
         chatGptMaxTokens: Int = K.ChatPdf.DefaultChatGptMaxTokens,
         chatMaxMessagesPerMonth: Int = K.ChatPdf.DefaultChatMaxMessagesPerMonth,
         stirlingApiEnabled: Bool = K.Stirling.DefaultEnabled) {
        self.proxyBaseUrl = proxyBaseUrl
        self.chatGptModel = chatGptModel
        self.chatGptMaxTokens = chatGptMaxTokens
        self.chatMaxMessagesPerMonth = chatMaxMessagesPerMonth
        self.stirlingApiEnabled = stirlingApiEnabled
    }
}

extension Container {
    var configService: Factory<ConfigService> {
        self { RemoteConfigManager() }.singleton
    }
}

/// Everything the manager needs from Firebase, behind a protocol.
///
/// Not for the sake of abstraction: the defect this was written for was one of
/// *lifecycle*, not of Firebase — the fetch was never asked for on Mac — and a
/// test of when we ask should not need a network, a project or a real device.
protocol RemoteConfigSource {
    /// Applies the settings and the in-app defaults. Called once, before any fetch.
    func prepare()
    /// Fetch and activate, as one step. Throws only if Firebase does.
    func fetchAndActivate() async throws
    /// The values in force right now — defaults until a fetch has landed.
    var data: RemoteConfigData { get }
}

/// The real one.
final class FirebaseRemoteConfigSource: RemoteConfigSource {

    private let remoteConfig: RemoteConfig

    private var expirationDuration: TimeInterval {
        return self.isTestUser
            ? K.RemoteConfigK.DebugRemoteConfigExpirationDuration
            : K.RemoteConfigK.DefaultRemoteConfigExpirationDuration
    }

    private var isTestUser: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    init(remoteConfig: RemoteConfig = RemoteConfig.remoteConfig()) {
        self.remoteConfig = remoteConfig
    }

    func prepare() {
        self.remoteConfig.configSettings = RemoteConfigSettings()
        self.remoteConfig.setDefaults(RemoteConfig.defaults)
    }

    func fetchAndActivate() async throws {
        let status = try await self.remoteConfig.fetch(withExpirationDuration: self.expirationDuration)
        guard status == .success else {
            print("RemoteConfigManager - Config not fetched. Status: '\(status.rawValue)'")
            return
        }
        print("RemoteConfigManager - Config fetched!")
        let changed = try await self.remoteConfig.activate()
        print("RemoteConfigManager - Config activated \(changed ? "with" : "without") changes")
    }

    var data: RemoteConfigData { RemoteConfigData(remoteConfig: self.remoteConfig) }
}

class RemoteConfigManager : ConfigService {

    lazy var remoteConfigData: CurrentValueSubject<RemoteConfigData, Never> = CurrentValueSubject<RemoteConfigData, Never>(self.source.data)

    private var sharedFetchConfigRequest: AnyPublisher<RemoteConfigData, Never>?
    private let source: RemoteConfigSource
    private var cancelBag = Set<AnyCancellable>()

    init(source: RemoteConfigSource = FirebaseRemoteConfigSource()) {
        self.source = source
        self.source.prepare()
    }

    // MARK: - ConfigService

    /// ⚠️ Do not make this depend on a notification again.
    ///
    /// The fetch used to hang off `didBecomeActive` alone. On Mac Catalyst that
    /// notification never reached the `onReceive` in `ContentView`, so the whole
    /// session ran on in-app defaults: `proxy_base_url` stayed empty, and with it
    /// `StirlingApiManager.isAvailable` stayed false — ChatPDF and the online
    /// tools were absent from the Mac app, and a failed Office conversion was
    /// never offered the online fallback. The iPhone, same code and same project,
    /// downloaded the five values in seconds. Launching always happens; being
    /// activated, apparently, does not.
    func start() {
        self.refresh()
    }

    func onApplicationDidBecomeActive() {
        self.refresh()
    }

    // MARK: Private methods

    private func refresh() {
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
                    try await self.source.fetchAndActivate()
                } catch {
                    print("RemoteConfigManager - Config not fetched or activated. Error: '\(error.localizedDescription)'")
                }
                self.sharedFetchConfigRequest = nil
                let remoteConfigData = self.source.data
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
            }
        }
        return result
    }
}
