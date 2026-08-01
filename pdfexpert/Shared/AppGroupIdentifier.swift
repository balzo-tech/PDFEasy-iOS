//
//  AppGroupIdentifier.swift
//  PdfExpert / PdfProWidget / ShareFileExtension
//
//  The same app group has two names. On iOS it is written exactly as it appears
//  in the developer portal; on macOS — and therefore in the Mac Catalyst build —
//  the sandbox only recognises it with the team identifier in front, which is
//  why the entitlements files use `$(TeamIdentifierPrefix)`. Ask for the wrong
//  one and `containerURL(forSecurityApplicationGroupIdentifier:)` quietly
//  returns nil: the widget finds no documents and the share extension writes
//  into nothing.
//
//  Every target that touches the group goes through here.
//

import Foundation

enum AppGroupIdentifier {

    /// Balzo's team identifier, the prefix macOS expects on the group name.
    /// It is fixed for the whole account and cannot be read back from a
    /// sandboxed process on iOS, so it lives here rather than being derived.
    private static let teamIdentifier = "G6RAKRKZPR"

    private static let bareName = "group.eu.balzo.pdfexpert"

    static var current: String {
        #if targetEnvironment(macCatalyst)
        "\(Self.teamIdentifier).\(Self.bareName)"
        #else
        Self.bareName
        #endif
    }
}
