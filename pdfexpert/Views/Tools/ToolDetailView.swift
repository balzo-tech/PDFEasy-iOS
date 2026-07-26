//
//  ToolDetailView.swift
//  PdfExpert
//
//  The third column when the Tools section is showing. On a phone a tool tile
//  starts its flow the moment it is tapped; there is no room to say more. Here
//  there is, so the tile only selects and this pane explains what the tool does
//  and what it needs before the user commits to a file picker.
//

import SwiftUI

struct ToolDetailView: View {

    let tool: PdfTool?
    let onRun: (PdfTool) -> Void

    var body: some View {
        Group {
            if let tool = self.tool {
                self.detail(for: tool)
            } else {
                self.emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(for tool: PdfTool) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            Image(systemName: tool.systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(tool.tint)
                .frame(width: 92, height: 92)
                .background(tool.tint.opacity(0.14), in: .circle)

            VStack(spacing: DS.Spacing.xs) {
                Text(tool.title)
                    .font(forCategory: .title2)
                    .foregroundStyle(ColorPalette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(tool.subtitle)
                    .font(forCategory: .body2)
                    .foregroundStyle(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                if tool.isPremium {
                    PremiumBadge()
                        .padding(.top, DS.Spacing.xxs)
                }
            }

            PrimaryActionButton(title: String(localized: "Start"), systemImage: tool.systemImage) {
                self.onRun(tool)
            }
            .frame(maxWidth: 280)
            .keyboardShortcut(.return, modifiers: [.command])

            Label(tool.category.title, systemImage: tool.category.systemImage)
                .font(forCategory: .caption1)
                .foregroundStyle(ColorPalette.textTertiary)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.xl)
        .navigationTitle(tool.title)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No tool selected", systemImage: "square.grid.2x2")
        } description: {
            Text("Pick a tool to see what it does.")
        }
    }
}

#Preview {
    NavigationStack {
        ToolDetailView(tool: ToolCatalog.allTools.first, onRun: { _ in })
    }
}
