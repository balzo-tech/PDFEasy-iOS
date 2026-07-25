//
//  ToolTileView.swift
//  PdfExpert
//
//  The tiles and chips used to reach the PDF tools.
//

import SwiftUI

/// Grid tile for a tool: tinted symbol, title, one-line description.
struct ToolTileView: View {

    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var isPremium: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .top) {
                    ToolIcon(systemImage: self.systemImage, tint: self.tint)
                    Spacer(minLength: 0)
                    if self.isPremium {
                        PremiumBadge(compact: true)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.title)
                        .font(forCategory: .body3)
                        .foregroundStyle(ColorPalette.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(self.subtitle)
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .contentShape(.rect(cornerRadius: DS.Radius.tile, style: .continuous))
        }
        .buttonStyle(PressableTileButtonStyle())
        .accessibilityLabel(Text(self.title))
        .accessibilityHint(Text(self.subtitle))
    }
}

/// Compact row used by search results and the "all tools" list.
struct ToolRowView: View {

    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var isPremium: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: DS.Spacing.sm) {
                ToolIcon(systemImage: self.systemImage, tint: self.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.title)
                        .font(forCategory: .body3)
                        .foregroundStyle(ColorPalette.textPrimary)
                        .lineLimit(1)
                    Text(self.subtitle)
                        .font(forCategory: .caption1)
                        .foregroundStyle(ColorPalette.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if self.isPremium {
                    PremiumBadge(compact: true)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorPalette.textTertiary)
            }
            .padding(DS.Spacing.sm)
            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .buttonStyle(PressableTileButtonStyle(radius: DS.Radius.control))
        .accessibilityLabel(Text(self.title))
        .accessibilityHint(Text(self.subtitle))
    }
}

/// Circular shortcut for the most-used tools, shown in a horizontal strip.
struct QuickActionView: View {

    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: self.systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(self.tint)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: DS.Size.quickActionIcon, height: DS.Size.quickActionIcon)
                    .background(self.tint.opacity(0.14), in: .circle)
                Text(self.title)
                    .font(forCategory: .caption1)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .frame(height: 32, alignment: .top)
            }
            .frame(width: 82)
            .contentShape(.rect)
        }
        .buttonStyle(PressableTileButtonStyle(radius: DS.Radius.control, dimsBackground: false))
        .accessibilityLabel(Text(self.title))
    }
}

/// Tinted symbol container shared by tiles and rows.
struct ToolIcon: View {

    let systemImage: String
    let tint: Color
    var side: CGFloat = DS.Size.toolIcon

    var body: some View {
        Image(systemName: self.systemImage)
            .font(.system(size: self.side * 0.45, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(self.tint)
            .frame(width: self.side, height: self.side)
            .background(self.tint.opacity(0.14),
                        in: .rect(cornerRadius: DS.Radius.icon, style: .continuous))
    }
}

/// Content-surface button: scales slightly and dims on press, like the system
/// grid cells in Files and Shortcuts.
struct PressableTileButtonStyle: ButtonStyle {

    var radius: CGFloat = DS.Radius.tile
    var dimsBackground: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if self.dimsBackground {
                    RoundedRectangle(cornerRadius: self.radius, style: .continuous)
                        .fill(ColorPalette.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: self.radius, style: .continuous)
                                .strokeBorder(ColorPalette.separator.opacity(0.7), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DS.Motion.quick, value: configuration.isPressed)
    }
}

#Preview("Tools") {
    ScrollView {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ToolTileView(title: "Merge PDF",
                             subtitle: "Combine files in the order you want",
                             systemImage: "square.stack",
                             tint: ColorPalette.categoryOrganize) {}
                ToolTileView(title: "Redact PDF",
                             subtitle: "Permanently black out content",
                             systemImage: "eye.slash",
                             tint: ColorPalette.categoryProtect,
                             isPremium: true) {}
            }
            ToolRowView(title: "Word to PDF",
                        subtitle: "Make DOC files easy to read",
                        systemImage: "doc.richtext",
                        tint: ColorPalette.categoryCreate) {}
            HStack {
                QuickActionView(title: "Scan", systemImage: "doc.viewfinder", tint: ColorPalette.categoryCreate) {}
                QuickActionView(title: "Sign", systemImage: "signature", tint: ColorPalette.categoryEdit) {}
            }
        }
        .padding()
    }
    .background(ColorPalette.background)
}
