//
//  PdfProCommands.swift
//  PdfExpert
//
//  Hardware-keyboard shortcuts. On iPadOS these also fill the list that appears
//  when the Command key is held down, which is how most people find out an app
//  has any. Everything routes through the coordinator, so a shortcut does the
//  same thing whichever shell is on screen.
//
//  Shortcuts that only make sense next to a particular control live with that
//  control instead — Save in the editor, Edit in the document detail pane.
//

import SwiftUI
import Factory

struct PdfProCommands: Commands {

    private var coordinator: MainCoordinator { Container.shared.mainCoordinator() }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New PDF") { self.run(.createPdf) }
                .keyboardShortcut("n", modifiers: [.command])
            Button("Scan") { self.run(.scan) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Image to PDF") { self.run(.imageToPdf) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Import PDF") { self.run(.importPdf) }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandMenu("Go") {
            Button("Files") { self.go(to: .files) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Tools") { self.go(to: .tools) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("ChatPDF") { self.go(to: .chat) }
                .keyboardShortcut("3", modifiers: [.command])
            Button("Search") { self.go(to: .search) }
                .keyboardShortcut("f", modifiers: [.command])

            Divider()

            Button("Settings") { self.showSettings() }
                .keyboardShortcut(",", modifiers: [.command])
        }
    }

    // MARK: - Actions

    /// Nothing here should reach past the onboarding, and nothing should move
    /// the ground under an open editor: a shortcut that silently switched the
    /// tab behind a modal would only be noticed on dismiss.
    private var isIdle: Bool {
        self.coordinator.rootView == .main && self.coordinator.pdfEditFlowData == nil
    }

    private func run(_ action: HomeAction) {
        guard self.isIdle else { return }
        ToolUsageTracker.registerUse(of: action)
        self.coordinator.runTool(action)
    }

    private func go(to tab: MainTab) {
        guard self.isIdle else { return }
        self.coordinator.tab = tab
    }

    private func showSettings() {
        guard self.isIdle else { return }
        self.coordinator.settingsShow = true
    }
}
