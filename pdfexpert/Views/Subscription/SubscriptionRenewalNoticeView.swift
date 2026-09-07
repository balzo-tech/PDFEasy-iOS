//
//  SubscriptionRenewalNoticeView.swift
//  PdfExpert
//
//  The reassurance shown on the paywall: on the yearly plan the renewal does
//  not arrive unannounced. Deliberately loud — a filled banner rather than a
//  footnote — because it is the objection the yearly plan has to answer, and a
//  line in the small print under the Continue button is not read.
//
//  Since 1.32 the promise carries a switch, on by default, so the reminder is
//  something the customer keeps rather than something we impose. The switch
//  changes what the banner says and nothing else: the warning before the
//  renewal is the one Apple sends of its own accord, and the app schedules no
//  notification of its own — the promise is kept either way.
//

import SwiftUI

struct SubscriptionRenewalNoticeView: View {

    static let reminderDefaultsKey = "expiryReminderWanted"

    /// On unless the customer turns it off, and remembered across sessions:
    /// reopening the paywall must not quietly re-arm something they declined.
    @AppStorage(SubscriptionRenewalNoticeView.reminderDefaultsKey) private var remindMe: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Toggle(isOn: self.$remindMe.animation(.snappy)) {
                HStack(alignment: .center, spacing: DS.Spacing.sm) {
                    Image(systemName: self.remindMe ? "bell.badge.fill" : "bell.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(ColorPalette.premium)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                    Text("With the yearly plan, we let you know before it expires.")
                        .font(forCategory: .body3)
                        .fontWeight(.semibold)
                        .foregroundStyle(ColorPalette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .tint(ColorPalette.premium)
            if self.remindMe {
                Text("We send you a notification the day before.")
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorPalette.premium.opacity(0.15),
                    in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .strokeBorder(ColorPalette.premium.opacity(0.45), lineWidth: 1)
        }
    }
}

#Preview("Renewal notice") {
    VStack {
        SubscriptionRenewalNoticeView()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorPalette.primaryBG)
}
