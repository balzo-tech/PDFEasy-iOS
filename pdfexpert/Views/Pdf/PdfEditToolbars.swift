//
//  PdfEditToolbars.swift
//  PdfExpert
//
//  The two bars under the page, and the panel behind the wrench.
//
//  What changed here: rotating, duplicating, deleting and reordering a page used
//  to be four entries buried in a menu of eighteen, which put "turn this page
//  the right way up" — something people do constantly, on the page in front of
//  them — at the same depth as "set PDF permissions". They are now a bar of
//  their own, always visible, always about the page on screen.
//
//  What is left in the panel is everything that acts on the *document*, grouped
//  and tinted by the same categories the Tools tab uses, and searchable, because
//  by the time a list needs grouping it also needs a search field.
//

import SwiftUI

// MARK: - Page actions

/// Acts on the page currently on screen. Its five buttons are gestures, not
/// tools: no confirmation, no sheet, immediate.
struct PdfEditPageBar: View {

    let canReorder: Bool
    let onTool: (EditorTool) -> Void

    private var tools: [EditorTool] {
        var tools: [EditorTool] = [.rotateLeft, .rotateRight, .duplicatePage, .deletePage]
        if self.canReorder { tools.append(.reorderPages) }
        return tools
    }

    var body: some View {
        GlassEffectContainer(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(self.tools) { tool in
                    Button {
                        self.onTool(tool)
                    } label: {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(tool == .deletePage ? ColorPalette.danger : ColorPalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: DS.Size.tapTarget)
                            .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .floatingGlass(radius: DS.Radius.control, interactive: true)
                    .accessibilityLabel(Text(tool.title))
                }
            }
        }
    }
}

// MARK: - Primary edits

/// The four edits people reach for constantly, under the page bar on a phone and
/// in the toolbar on a wide window.
struct PdfEditPrimaryBar: View {

    let onTool: (EditorTool) -> Void

    static let tools: [EditorTool] = [.addPage, .signature, .addText, .fillForm]

    var body: some View {
        GlassEffectContainer(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(Self.tools) { tool in
                    Button {
                        self.onTool(tool)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 18, weight: .medium))
                            Text(tool.title)
                                .font(forCategory: .caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(ColorPalette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .contentShape(.rect(cornerRadius: DS.Radius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .floatingGlass(radius: DS.Radius.control, interactive: true)
                    .accessibilityLabel(Text(tool.title))
                }
            }
        }
    }
}

// MARK: - The panel

/// Everything that acts on the whole document. A sheet rather than a menu: at
/// eighteen entries a menu is a wall of text, and the catalog already knows how
/// to describe a tool — name, symbol, category tint, premium badge.
struct PdfEditToolPanel: View {

    let isPasswordSet: Bool
    let pageCount: Int
    let onTool: (EditorTool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private static let columns = [GridItem(.adaptive(minimum: 104, maximum: 200), spacing: DS.Spacing.xs)]

    /// How a tool's tile is addressed from a UI test. Independent of the
    /// language the app is running in, unlike its title.
    static func tileIdentifier(for tool: EditorTool) -> String { "editorTool.\(tool.rawValue)" }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.lg, pinnedViews: []) {
                    ForEach(EditorToolGroup.filtered(by: self.query)) { group in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(group.title)
                                .font(forCategory: .caption1)
                                .foregroundStyle(ColorPalette.textSecondary)
                                .padding(.horizontal, DS.Spacing.xxs)
                            LazyVGrid(columns: Self.columns, spacing: DS.Spacing.xs) {
                                ForEach(group.tools) { tool in
                                    self.tile(for: tool)
                                }
                            }
                        }
                    }
                    if EditorToolGroup.filtered(by: self.query).isEmpty {
                        ContentUnavailableView.search(text: self.query)
                            .frame(maxWidth: .infinity)
                            .padding(.top, DS.Spacing.xxl)
                    }
                }
                .padding(DS.Spacing.md)
                // The search field floats over the bottom of the sheet on iOS 26;
                // without this the last row of tiles sits under it.
                .padding(.bottom, DS.Spacing.xxl + DS.Spacing.lg)
                .readableColumn()
            }
            .background(ColorPalette.background)
            .searchable(text: self.$query, prompt: Text("Search tools"))
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { self.dismiss() }
                }
            }
        }
    }

    private func tile(for tool: EditorTool) -> some View {
        Button {
            self.dismiss()
            self.onTool(tool)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Image(systemName: self.systemImage(for: tool))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tool.tint)
                    .frame(width: DS.Size.toolIcon, height: DS.Size.toolIcon)
                    .background(tool.tint.opacity(0.14), in: .rect(cornerRadius: DS.Radius.icon, style: .continuous))
                Text(self.title(for: tool))
                    .font(forCategory: .caption1)
                    .fontWeight(.medium)
                    .foregroundStyle(ColorPalette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    // "Make Searchable (OCR)" is the longest name in the catalog
                    // and does not fit two lines at full size on a phone.
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .contentCard()
        }
        .buttonStyle(PressableTileButtonStyle())
        .hoverEffect(.lift)
        .disabled(self.isDisabled(tool))
        .opacity(self.isDisabled(tool) ? 0.4 : 1)
        // Named, because half these tools also have a button in the bar under
        // the page carrying the same title: a UI test asking for "Reorder pages"
        // otherwise gets the one behind the sheet and taps the sheet instead.
        .accessibilityIdentifier(Self.tileIdentifier(for: tool))
    }

    /// The password entry says what it will do, which depends on the document.
    private func title(for tool: EditorTool) -> String {
        guard tool == .password else { return tool.title }
        return self.isPasswordSet ? String(localized: "Unlock") : String(localized: "Protect")
    }

    private func systemImage(for tool: EditorTool) -> String {
        guard tool == .password else { return tool.systemImage }
        return self.isPasswordSet ? "lock.open" : "lock"
    }

    /// Greyed out rather than hidden: a tool that vanishes when the document is
    /// one page long reads as a bug, and the user cannot tell what they are
    /// missing.
    private func isDisabled(_ tool: EditorTool) -> Bool {
        tool.needsSeveralPages && self.pageCount < 2
    }
}
