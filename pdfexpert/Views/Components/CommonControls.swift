//
//  CommonControls.swift
//  PdfExpert
//
//  Small shared building blocks: section headers, the primary call to action
//  and the floating "new document" button.
//

import SwiftUI

/// Section title with an optional trailing accessory, used above grids and lists.
struct SectionHeaderView<Accessory: View>: View {

    let title: String
    var subtitle: String? = nil
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(forCategory: .title3)
                    .foregroundStyle(ColorPalette.textPrimary)
                if let subtitle = self.subtitle {
                    Text(subtitle)
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                }
            }
            Spacer(minLength: DS.Spacing.xs)
            self.accessory()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeaderView where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() })
    }
}

/// The screen's main action. Prominent glass so it reads as the one thing to
/// press, tinted with the brand accent.
struct PrimaryActionButton: View {

    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: DS.Spacing.xs) {
                if let systemImage = self.systemImage {
                    Image(systemName: systemImage)
                }
                Text(self.title)
            }
            .font(forCategory: .button)
            .frame(maxWidth: .infinity)
            .frame(minHeight: DS.Size.tapTarget)
        }
        .buttonStyle(.glassProminent)
        .tint(ColorPalette.accent)
        .buttonBorderShape(.capsule)
        .disabled(!self.isEnabled)
    }
}

/// Secondary action: plain glass, no tint, sits next to a `PrimaryActionButton`.
struct SecondaryActionButton: View {

    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: DS.Spacing.xs) {
                if let systemImage = self.systemImage {
                    Image(systemName: systemImage)
                }
                Text(self.title)
            }
            .font(forCategory: .button)
            .frame(minHeight: DS.Size.tapTarget)
            .padding(.horizontal, DS.Spacing.md)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .tint(ColorPalette.textPrimary)
    }
}

/// Round glass button for icon-only actions floating over content.
struct GlassIconButton: View {

    let systemImage: String
    var accessibilityLabel: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Image(systemName: self.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: DS.Size.tapTarget, height: DS.Size.tapTarget)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(self.tint ?? ColorPalette.textPrimary)
        .accessibilityLabel(Text(self.accessibilityLabel))
    }
}

/// "PRO" pill marking a premium-gated feature.
struct PremiumBadge: View {

    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: self.compact ? 9 : 10, weight: .bold))
            if !self.compact {
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .textCase(.uppercase)
            }
        }
        .foregroundStyle(ColorPalette.premium)
        .padding(.horizontal, self.compact ? 5 : 7)
        .padding(.vertical, 3)
        .background(ColorPalette.premium.opacity(0.15), in: .capsule)
        .accessibilityLabel(Text("Premium feature"))
    }
}

#Preview("Controls") {
    VStack(spacing: DS.Spacing.lg) {
        SectionHeaderView(title: "Organize", subtitle: "Pages and documents")
        PrimaryActionButton(title: "New document", systemImage: "plus") {}
        HStack {
            SecondaryActionButton(title: "Share", systemImage: "square.and.arrow.up") {}
            GlassIconButton(systemImage: "trash", accessibilityLabel: "Delete") {}
            PremiumBadge()
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorPalette.background)
}
