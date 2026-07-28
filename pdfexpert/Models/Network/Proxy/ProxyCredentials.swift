//
//  ProxyCredentials.swift
//  PdfExpert
//
//  What the app presents to the proxy instead of an API key.
//
//  Two things, neither of them a secret worth stealing: a short-lived App Check
//  token, which Firebase only issues after Apple has vouched for this binary on
//  this device, and the id Apple gave the subscription. Copied off the wire
//  neither is much use — the token expires in under an hour and is bound to the
//  app, and the id alone gets you nothing without a token to go with it.
//
//  Both are fetched per request rather than cached here: Firebase already caches
//  the token and refreshes it when it is close to expiring, and doing it again
//  would only add a second place for a stale one to hide.
//

import Foundation
import Combine
import Factory
import FirebaseAppCheck

extension Container {
    var proxyCredentialsProvider: Factory<ProxyCredentialsProvider> {
        self { FirebaseProxyCredentialsProvider() }.singleton
    }
}

struct ProxyCredentials {
    let appCheckToken: String
    let originalTransactionId: String

    /// The headers the Worker reads. Names match `proxy/src/index.ts`.
    var headers: [String: String] {
        [
            "X-App-Check": self.appCheckToken,
            "X-Original-Transaction-Id": self.originalTransactionId,
        ]
    }
}

enum ProxyCredentialsError: LocalizedError {
    /// No active subscription, so there is nothing to present. The proxy would
    /// refuse anyway; failing here saves the round trip and gives the caller an
    /// error it can phrase properly.
    case notSubscribed
    /// App Attest could not answer. On a real device this is usually a network
    /// problem; in the simulator it means the debug token is not registered.
    case attestationUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .notSubscribed:
            return String(localized: "This feature is part of the subscription.")
        case .attestationUnavailable:
            return String(localized: "Could not verify this device. Check your connection and try again.")
        }
    }
}

protocol ProxyCredentialsProvider {
    func credentials() async throws -> ProxyCredentials
    /// Whether there is any point in trying — used to decide whether to offer a
    /// feature at all, not as a security check.
    var canAuthenticate: Bool { get }
}

final class FirebaseProxyCredentialsProvider: ProxyCredentialsProvider {

    @Injected(\.store) private var store

    var canAuthenticate: Bool {
        self.store.originalTransactionId.value != nil
    }

    func credentials() async throws -> ProxyCredentials {
        guard let transactionId = self.store.originalTransactionId.value else {
            throw ProxyCredentialsError.notSubscribed
        }
        do {
            let token = try await AppCheck.appCheck().token(forcingRefresh: false)
            return ProxyCredentials(appCheckToken: token.token,
                                    originalTransactionId: transactionId)
        } catch {
            throw ProxyCredentialsError.attestationUnavailable(error.localizedDescription)
        }
    }
}
