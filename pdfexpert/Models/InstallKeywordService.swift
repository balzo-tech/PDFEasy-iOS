//
//  InstallKeywordService.swift
//  PdfExpert
//
//  Which Apple Search Ads keyword this install came from, so the app can meet
//  someone with the thing they were searching for instead of the average tour.
//
//  The token comes from AdServices and is free: `AAAttribution.attributionToken()`
//  is local and synchronous. Exchanging it for the attribution record is one POST
//  to Apple. The Grogu SDK sends the same token to the backend for the campaign
//  reporting — this asks Apple the same question a second time, because the
//  backend has no endpoint the app can read the answer back from, and one POST
//  is cheaper than building one.
//
//  Measured on 1.226 attributed installs (see `install-keyword-is-knowable`):
//  Apple answers at the first attempt in practice — 1,06 attempts on average,
//  94,9% inside ten seconds. So the retry here is short on purpose: three tries
//  a few seconds apart cover the onboarding window, and anything slower than
//  that has already missed the moment it exists for.
//
//  The answer never changes, so it is asked once per install and remembered.
//

import Foundation
import Factory

#if canImport(AdServices)
import AdServices
#endif

protocol InstallKeywordProviding {
    /// The keyword id, once known. Nil while unresolved, and for organic
    /// installs, and for the Discovery campaigns — a search match carries no
    /// keyword at all, which is the trap recorded in `trials-per-campaign-from-db`.
    var keywordId: String? { get }
    /// Asks Apple, unless the answer is already remembered. Safe to call twice.
    func resolve() async
}

extension Container {
    var installKeywordService: Factory<InstallKeywordProviding> {
        self { InstallKeywordService() }.singleton
    }
}

final class InstallKeywordService: InstallKeywordProviding {

    private enum Key {
        static let keywordId = "installKeywordId"
        static let settled = "installKeywordSettled"
    }

    private static let endpoint = URL(string: "https://api-adservices.apple.com/api/v1/")!
    private static let attempts = 3
    private static let pauseBetweenAttempts: Duration = .seconds(3)

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var keywordId: String? {
        self.defaults.string(forKey: Key.keywordId)
    }

    func resolve() async {
        // Settled covers both outcomes: a keyword, and a definite "there is
        // none" for an organic install. Without it every launch would ask Apple
        // again on behalf of users who will never have an answer.
        guard !self.defaults.bool(forKey: Key.settled) else { return }

        guard let token = Self.attributionToken() else {
            self.defaults.set(true, forKey: Key.settled)
            return
        }

        for attempt in 1...Self.attempts {
            switch await Self.ask(with: token) {
            case .answer(let keywordId):
                if let keywordId {
                    self.defaults.set(keywordId, forKey: Key.keywordId)
                }
                self.defaults.set(true, forKey: Key.settled)
                return
            case .notYet:
                // 404 means the record is not written yet, which is the one case
                // worth waiting for. Everything else is final.
                if attempt < Self.attempts {
                    try? await Task.sleep(for: Self.pauseBetweenAttempts)
                }
            case .giveUp:
                self.defaults.set(true, forKey: Key.settled)
                return
            }
        }
        // Out of attempts: leave it unsettled so a later launch can try again.
        // The onboarding has been and gone by then, but the answer is still
        // worth having for anything that runs after it.
    }

    // MARK: - Apple

    private static func attributionToken() -> String? {
        #if canImport(AdServices)
        if #available(iOS 14.3, *) {
            return try? AAAttribution.attributionToken()
        }
        #endif
        return nil
    }

    private enum Reply {
        /// Apple answered. The keyword is nil for organic installs and for
        /// search-match campaigns, which carry no keyword.
        case answer(keywordId: String?)
        case notYet
        case giveUp
    }

    private static func ask(with token: String) async -> Reply {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(token.utf8)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .giveUp }
            switch http.statusCode {
            case 200:
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return .giveUp
                }
                // Apple sends the ids as numbers; a keyword id of 0 is "none",
                // not a keyword called zero.
                guard let raw = json["keywordId"] as? NSNumber, raw.int64Value > 0 else {
                    return .answer(keywordId: nil)
                }
                return .answer(keywordId: String(raw.int64Value))
            case 404:
                return .notYet
            default:
                return .giveUp
            }
        } catch {
            return .notYet
        }
    }
}
