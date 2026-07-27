//
//  ProjectInfo.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/07/23.
//

import Foundation

class ProjectInfo {

    // SECURITY NOTE: These keys are compiled into the client as XOR-obfuscated
    // bytes (see the "Generate Secrets" build phase and ObfuscatedSecrets.swift).
    // The real values live only in the git-ignored `pdfexpert/Resources/ProjectInfo.plist`
    // and are NO LONGER bundled into the app, so unzipping the IPA no longer exposes
    // them and `strings` on the binary reveals nothing (the XOR pad is random per build).
    // This only raises the bar: a determined runtime attacker (jailbreak/hooking,
    // or proxying the traffic) can still extract a key once it is used. The accepted
    // future mitigation is a thin server-side proxy that holds the real key and
    // enforces quotas. A key missing from the plist deobfuscates to an empty string,
    // so builds without a populated ProjectInfo.plist still compile and run; the
    // dependent feature then fails gracefully with a clear error.
    static var openAiApiKey: String { ObfuscatedSecrets.openAiApiKey.value }

    static var stirlingApiKey: String { ObfuscatedSecrets.stirlingApiKey.value }

    /// Apple Search Ads attribution (see `AppleAttributionPlatform`). Empty when
    /// the plist has no key, which is how the SDK stays switched off rather than
    /// being configured with nothing — `configure` is idempotent and cannot be
    /// undone.
    static var appleAttributionApiKey: String { ObfuscatedSecrets.appleAttributionApiKey.value }

    /// Kept for call-site compatibility (invoked from `AppDelegate`). The secrets
    /// are resolved from generated code rather than a bundled plist, so this simply
    /// forces them to be evaluated once at launch.
    static func validate() {
        _ = Self.openAiApiKey
        _ = Self.stirlingApiKey
        _ = Self.appleAttributionApiKey
    }
}
