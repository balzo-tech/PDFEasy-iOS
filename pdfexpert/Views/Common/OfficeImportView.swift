//
//  OfficeImportView.swift
//  PdfExpert
//
//  Presentation layer for `OfficeImportCoordinator`: the "local conversion failed"
//  offer, the shared online-processing disclosure and the paywall. Applied by every
//  host that can import an Office / iWork document (Home, editor, chat selection) —
//  the loader and the error come from each host's own async channel, which the
//  coordinator drives.
//

import SwiftUI

struct OfficeImportAlerts: ViewModifier {

    @ObservedObject var coordinator: OfficeImportCoordinator

    func body(content: Content) -> some View {
        content
            .alert(String(localized: "Conversion failed"),
                   isPresented: self.$coordinator.fallbackAlertShow,
                   actions: {
                Button(String(localized: "Cancel"), role: .cancel) {
                    self.coordinator.onFallbackDeclined()
                }
                Button(String(localized: "Convert online")) {
                    self.coordinator.onFallbackAccepted()
                }
            }, message: {
                Text("This document could not be converted on your device. You can convert it with our high-quality online service.")
            })
            .alert(String(localized: "Online conversion"),
                   isPresented: self.$coordinator.disclosureAlertShow,
                   actions: {
                Button(String(localized: "Cancel"), role: .cancel) {
                    self.coordinator.onDisclosureCancelled()
                }
                Button(String(localized: "Continue")) {
                    self.coordinator.onDisclosureAccepted()
                }
            }, message: {
                Text("This document is sent securely to the conversion service and deleted after processing.")
            })
            .showSubscriptionView(self.$coordinator.monetizationShow,
                                  onComplete: { self.coordinator.onMonetizationClose() })
    }
}

extension View {
    func showOfficeImportAlerts(coordinator: OfficeImportCoordinator) -> some View {
        self.modifier(OfficeImportAlerts(coordinator: coordinator))
    }
}
