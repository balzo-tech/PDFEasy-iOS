//
//  AppCheckProviderFactory.swift
//  PdfExpert
//
//  Which kind of proof of identity this build can offer.
//
//  On a device: App Attest, where Apple vouches for both the binary and the
//  hardware. In the simulator, and in the unit and UI test bundles, App Attest
//  is unavailable — there is no Secure Enclave to attest with — so a debug build
//  uses Firebase's debug provider instead. That prints a token on first launch
//  which has to be registered in the Firebase console before it is accepted; an
//  unregistered debug token is refused exactly like a forged one.
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
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
