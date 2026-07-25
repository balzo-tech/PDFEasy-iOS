//
//  SettingsView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 03/04/23.
//

import SwiftUI
import Factory
import Combine
import StoreKit

struct DisclamerItem: Hashable {
    let text: String
    let urlString: String
}

struct SettingsView: View {

    @Environment(\.dismiss) var dismiss

    @Injected(\.store) private var store

    @State private var isPremium: Bool = false
    @State private var subscriptionShow: Bool = false
    @State private var restoreInProgress: Bool = false
    @State private var restoreResultShow: Bool = false

    private let disclamers = [
        DisclamerItem(text: String(localized: "Privacy policy"), urlString: K.Misc.PrivacyPolicyUrlString),
        DisclamerItem(text: String(localized: "Terms and conditions"), urlString: K.Misc.TermsAndConditionsUrlString)
    ]

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                if self.isPremium {
                    self.premiumRow
                } else {
                    self.upgradeRow
                }
                Button {
                    self.restorePurchases()
                } label: {
                    Label("Restore purchases", systemImage: "arrow.clockwise")
                }
                .disabled(self.restoreInProgress)
            } header: {
                Text("Subscription")
            }

            Section {
                ForEach(self.disclamers, id: \.self) { disclamer in
                    Link(destination: URL(string: disclamer.urlString)!) {
                        HStack {
                            Text(disclamer.text)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ColorPalette.textTertiary)
                        }
                    }
                }
                LabeledContent("Version", value: self.appVersion)
            } header: {
                Text("About")
            }
        }
        .tint(ColorPalette.accent)
        .showSubscriptionView(self.$subscriptionShow, onComplete: {})
        .alert(String(localized: "Restore purchases"), isPresented: self.$restoreResultShow, actions: {
            Button("Ok", role: .cancel, action: {})
        }, message: {
            Text(self.isPremium
                 ? String(localized: "Your subscription is active again.")
                 : String(localized: "We could not find a purchase to restore."))
        })
        .onReceive(self.store.isPremium) { self.isPremium = $0 }
        .onAppear() {
            Container.shared.analyticsManager().track(event: .reportScreen(.settings))
        }
    }

    private var premiumRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorPalette.premium)
                .frame(width: 30, height: 30)
                .background(ColorPalette.premium.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text("PDF Pro")
                    .font(forCategory: .body3)
                    .foregroundStyle(ColorPalette.textPrimary)
                Text("Every tool unlocked")
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var upgradeRow: some View {
        Button {
            self.subscriptionShow = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorPalette.premium)
                    .frame(width: 30, height: 30)
                    .background(ColorPalette.premium.opacity(0.15), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Go premium")
                        .font(forCategory: .body3)
                        .foregroundStyle(ColorPalette.textPrimary)
                    Text("Unlock every tool")
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorPalette.textTertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    /// Same two steps the paywall's restore does: ask StoreKit to sync, then
    /// re-read entitlements so `isPremium` reflects the result.
    private func restorePurchases() {
        self.restoreInProgress = true
        Task { @MainActor in
            try? await AppStore.sync()
            try? await self.store.refreshAll()
            self.restoreInProgress = false
            self.restoreResultShow = true
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Settings")
        }
    }
}
