//
//  SubscriptionRenewalNoticeView.swift
//  PdfExpert
//
//  The reassurance shown on every paywall: on the yearly plan the renewal does
//  not arrive unannounced. Deliberately loud — a filled banner rather than a
//  footnote — because it is the objection the yearly plan has to answer, and a
//  line in the small print under the Continue button is not read.
//
//  Shared by all three paywall layouts (pairs, vertical, picker) so the promise
//  is worded the same wherever the paywall is shown.
//

import SwiftUI

struct SubscriptionRenewalNoticeView: View {

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ColorPalette.premium)
                .accessibilityHidden(true)
            Text("With the yearly plan, we let you know before it expires.")
                .font(forCategory: .body3)
                .fontWeight(.semibold)
                .foregroundStyle(ColorPalette.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityElement(children: .combine)
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
