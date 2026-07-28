//
//  ProjectInfo.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/07/23.
//

import Foundation

class ProjectInfo {

    // The OpenAI and Stirling keys used to be here, compiled in as XOR-obfuscated
    // bytes. The note that stood in this place admitted what that was worth — "a
    // determined runtime attacker can still extract a key once it is used" — and
    // named the fix: "a thin server-side proxy that holds the real key and
    // enforces quotas". That proxy exists now, in `proxy/`, and the app holds
    // neither key. What it presents instead is an App Check token and the id of
    // its subscription; see `ProxyCredentials`.
    //
    // One key is left, and it is a different shape of secret: it identifies the
    // app to an attribution service, it buys nothing, and the SDK insists on
    // having it in-process.

    /// Apple Search Ads attribution (see `AppleAttributionPlatform`). Empty when
    /// the plist has no key, which is how the SDK stays switched off rather than
    /// being configured with nothing — `configure` is idempotent and cannot be
    /// undone.
    static var appleAttributionApiKey: String { ObfuscatedSecrets.appleAttributionApiKey.value }

    /// Kept for call-site compatibility (invoked from `AppDelegate`). The secret
    /// is resolved from generated code rather than a bundled plist, so this simply
    /// forces it to be evaluated once at launch.
    static func validate() {
        _ = Self.appleAttributionApiKey
    }
}
