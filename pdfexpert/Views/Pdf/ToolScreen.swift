//
//  ToolScreen.swift
//  PdfExpert
//
//  The chrome around a tool's form, decided by where the tool was opened from.
//
//  The same screens are reached two ways: from the Tools tab, where a tool is a
//  modal with a close button because there is no document behind it to go back
//  to, and from the editor, where it is pushed onto the document's own stack and
//  wants a back button instead. Before this each tool hard-coded the first case
//  — its own `NavigationStack` plus a close button — which is why the editor
//  could only ever present them modally.
//
//  Wrapping the form in `ToolScreen` lets the host decide. `@Environment(\.dismiss)`
//  keeps working either way: in a pushed screen it pops, in a modal it closes.
//

import SwiftUI

private struct PushedToolScreenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    /// Set by the editor on everything it pushes. A tool reads it only through
    /// `ToolScreen`; nothing else should need to know.
    var isPushedToolScreen: Bool {
        get { self[PushedToolScreenKey.self] }
        set { self[PushedToolScreenKey.self] = newValue }
    }
}

/// The confirming button in the navigation bar, for the tools that have one.
struct ToolScreenAction {

    let title: String
    var isEnabled: Bool = true
    let action: () -> Void
}

struct ToolScreen<Content: View>: View {

    let title: String
    /// Shown trailing, in both presentations.
    var confirm: ToolScreenAction? = nil
    /// What the leading button does when the screen is modal. Pushed, there is a
    /// back button already and this is dropped — two ways back on one screen is
    /// one too many.
    var onCancel: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.isPushedToolScreen) private var isPushed
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if self.isPushed {
            self.chrome(self.content())
        } else {
            NavigationStack {
                self.chrome(self.content())
                    .addSystemCloseButton(color: ColorPalette.primaryText, onPress: {
                        if let onCancel = self.onCancel { onCancel() } else { self.dismiss() }
                    })
            }
        }
    }

    private func chrome(_ content: Content) -> some View {
        content
            .navigationTitle(self.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let confirm = self.confirm {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(confirm.title, action: confirm.action)
                            .disabled(!confirm.isEnabled)
                            .fontWeight(.semibold)
                    }
                }
            }
    }
}
