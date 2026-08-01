//
//  MacWindowSupport.swift
//  PdfExpert
//
//  What the Mac needs that no iPad does: a window with a floor under its size,
//  and a title bar that does not repeat a title the sidebar already shows.
//
//  A Catalyst app gets its window from the same `WindowGroup` the iPad uses, so
//  there is no scene delegate to configure it in. It is done once the scene has
//  connected, from the root view.
//

import SwiftUI

enum MacWindowSupport {

    /// Below this the three columns stop being three columns: the split view
    /// starts hiding the sidebar, and the detail column — a page of a PDF — is
    /// down to a strip. It is a floor, not a preferred size.
    private static let minimumWindowSize = CGSize(width: 960, height: 660)

    static func configureConnectedScenes() {
        #if targetEnvironment(macCatalyst)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }

            windowScene.sizeRestrictions?.minimumSize = Self.minimumWindowSize
            // Left at its default the maximum tracks the minimum on some scenes,
            // which pins the window to that size instead of merely bounding it.
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                               height: CGFloat.greatestFiniteMagnitude)

            // The title bar is left exactly as Catalyst set it up. Hiding the
            // title, or clearing the toolbar, takes the sidebar's own header
            // with it — the app's name and the Settings button live there.
        }
        #endif
    }
}

extension View {

    /// No-op everywhere but the Mac.
    func configuresMacWindow() -> some View {
        self.onAppear { MacWindowSupport.configureConnectedScenes() }
    }
}
