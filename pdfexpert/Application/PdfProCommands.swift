//
//  PdfProCommands.swift
//  PdfExpert
//
//  Hardware-keyboard shortcuts. On iPadOS these also fill the list that appears
//  when the Command key is held down, which is how most people find out an app
//  has any. On the Mac they are the menu bar, where a missing File ▸ Open is not
//  a shortcut nobody found but a menu that looks broken.
//
//  ⚠️ The File group is **not** here. `CommandGroup(replacing: .newItem)` needs a
//  "New" group to replace, and UIKit only builds one for apps that support more
//  than one scene; this app is single-window, so every button placed there was
//  dropped on the floor — no menu item, and no working shortcut either (⌘N, ⌘O,
//  ⌘⇧S, ⌘⇧P all did nothing on the Mac). It is built by hand instead, in
//  `AppDelegate.buildMenu(with:)`, which is also where the system's own inert
//  File items are taken out of the way.
//
//  Everything routes through `PdfProMenuActions`, so a shortcut does the same
//  thing whichever shell — or menu bar — it was fired from.
//
//  Shortcuts that only make sense next to a particular control live with that
//  control instead — Save in the editor, Edit in the document detail pane.
//

import SwiftUI
import Factory

/// What a menu item does, with nothing about where it is shown. Two places need
/// it: the commands below, and the app delegate, which builds the File menu by
/// hand on the Mac.
enum PdfProMenuActions {

    private static var coordinator: MainCoordinator { Container.shared.mainCoordinator() }

    /// Nothing should reach past the onboarding, and nothing should move the
    /// ground under an open editor: a shortcut that silently switched the tab
    /// behind a modal would only be noticed on dismiss.
    static var isIdle: Bool {
        Self.coordinator.rootView == .main && Self.coordinator.pdfEditFlowData == nil
    }

    static func run(_ action: HomeAction) {
        guard Self.isIdle else { return }
        ToolUsageTracker.registerUse(of: action)
        Self.coordinator.runTool(action)
    }

    static func go(to tab: MainTab) {
        guard Self.isIdle else { return }
        Self.coordinator.tab = tab
    }

    static func showSettings() {
        guard Self.isIdle else { return }
        Self.coordinator.settingsShow = true
    }
}

struct PdfProCommands: Commands {

    var body: some Commands {
        // The Mac keeps Settings where every other Mac app keeps it.
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { PdfProMenuActions.showSettings() }
                .keyboardShortcut(",", modifiers: [.command])
        }

        // No sidebar command here on purpose: adding one that duplicates a
        // shortcut the system already owns makes the menu bar refuse to build at
        // all — the app dies on launch, before a window is ever shown.

        CommandMenu("Go") {
            Button("Files") { PdfProMenuActions.go(to: .files) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Tools") { PdfProMenuActions.go(to: .tools) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Scanner") { PdfProMenuActions.go(to: .scanner) }
                .keyboardShortcut("3", modifiers: [.command])
            Button("ChatPDF") { PdfProMenuActions.go(to: .chat) }
                .keyboardShortcut("4", modifiers: [.command])
            Button("Search") { PdfProMenuActions.go(to: .search) }
                .keyboardShortcut("f", modifiers: [.command])
        }

#if !targetEnvironment(macCatalyst)
        // iPadOS gets the same set through SwiftUI: there the hardware-keyboard
        // list is built from these, and the File group is not involved.
        CommandGroup(replacing: .newItem) {
            Button("New PDF") { PdfProMenuActions.run(.createPdf) }
                .keyboardShortcut("n", modifiers: [.command])
            Button("Open…") { PdfProMenuActions.run(.importPdf) }
                .keyboardShortcut("o", modifiers: [.command])
            Button("Scan") { PdfProMenuActions.run(.scan) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Image to PDF") { PdfProMenuActions.run(.imageToPdf) }
                .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Button("Merge PDFs") { PdfProMenuActions.run(.merge) }
            Button("Split PDF") { PdfProMenuActions.run(.split) }
            Button("Compress PDF") { PdfProMenuActions.run(.compressPdf) }
        }
#endif
    }
}
