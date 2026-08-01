//
//  UIDevice+Extensions.swift
//  PdfExpert
//
//  Almost every `userInterfaceIdiom == .pad` in this app was not really asking
//  about an iPad. It was asking whether the app has room and a pointer: whether
//  a picker can be a panel instead of taking over the screen, whether a choice
//  belongs in an alert rather than an action sheet pinned to the bottom edge.
//
//  The Mac answers `.mac` to that question, so every one of those checks would
//  have handed the Mac the phone's shape — file pickers as full-screen covers,
//  sheets with drag indicators, dialogs sliding up from the bottom of a window.
//  They all go through here instead.
//

import UIKit

extension UIDevice {

    /// True where the app lives in a resizable window with a pointer next to it:
    /// iPad and Mac.
    static var hasDesktopClassLayout: Bool {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad, .mac: true
        default: false
        }
    }

    /// True only in the Mac Catalyst build. Reserved for the handful of places
    /// where the Mac needs something an iPad does not — a window that never
    /// collapses to a tab bar, a menu bar that has to carry its own weight.
    static var isMac: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }
}
