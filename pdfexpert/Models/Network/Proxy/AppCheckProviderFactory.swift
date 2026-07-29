//
//  AppCheckProviderFactory.swift
//  PdfExpert
//
//  Which kind of proof of identity this build can offer.
//
//  On a device: App Attest, where Apple vouches for both the binary and the
//  hardware. In the simulator, and in the unit and UI test bundles, App Attest
//  is unavailable — there is no Secure Enclave to attest with — so a debug build
//  uses Firebase's debug provider instead. That token has to be registered in
//  the Firebase console before it is accepted; an unregistered debug token is
//  refused exactly like a forged one.
//
//  The token is printed here rather than by Firebase. The line everyone looks
//  for — `[Firebase/AppCheck][I-FAA001001] Firebase App Check debug token` — is
//  logged by `AppCheckDebugProviderFactory`, the factory Firebase ships, and
//  this is a different factory: it builds the provider itself so that a release
//  build gets App Attest and nothing else, and in doing so it never runs that
//  log line. Without the print below the token exists, works, and is invisible.
//
//  A release build has no fallback on purpose. If App Attest cannot answer there
//  is no proof to offer, and the honest outcome is a refusal from the proxy
//  rather than a second, weaker door.
//

import Foundation
import FirebaseCore
import FirebaseAppCheck

class PdfProAppCheckProviderFactory: NSObject, AppCheckProviderFactory {

    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        let provider = AppCheckDebugProvider(app: app)
        // `currentDebugToken` is what will actually be sent: the
        // FIRAAppCheckDebugToken environment variable if the scheme sets one,
        // otherwise a token generated once and kept in UserDefaults. Printing
        // the one in use — not just the local one — is the difference between
        // registering the right token and registering a token nobody sends.
        if let token = provider?.currentDebugToken() {
            print("""

            ┌─ App Check ───────────────────────────────────────────────
            │ Debug token: \(token)
            │ Register it in the Firebase console of project \
            "\(app.options.projectID ?? "?")":
            │ App Check → \(app.options.bundleID) → ⋮ → Manage debug tokens
            └───────────────────────────────────────────────────────────

            """)
        }
        return provider
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
