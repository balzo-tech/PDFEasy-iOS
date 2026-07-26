//
//  DesignSystem.swift
//  PdfExpert
//
//  Layout, shape and motion constants shared by the whole UI, plus the two
//  surface treatments the app uses.
//
//  A note on Liquid Glass: glass belongs to the *chrome* — the tab bar, the
//  toolbars, floating controls above content. Content itself (tool tiles, file
//  rows, cards) sits on an opaque surface. Glassing everything would stack
//  translucency on translucency and cost both contrast and legibility, which is
//  exactly what the material is designed to avoid.
//

import SwiftUI

enum DS {

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 22
        static let tile: CGFloat = 20
        static let control: CGFloat = 14
        static let thumbnail: CGFloat = 10
        static let icon: CGFloat = 11
    }

    enum Size {
        /// Side of the tinted icon container inside a tool tile.
        static let toolIcon: CGFloat = 40
        /// Minimum hit target, per the HIG.
        static let tapTarget: CGFloat = 44
        static let quickActionIcon: CGFloat = 54
    }

    enum Layout {
        /// Widest a single column of controls should get. Past this a form stops
        /// reading as a form: the label ends up a hand's width from its own
        /// switch, and the eye has to travel the whole window to pair them.
        /// Same number as the signature sheet's iPad width.
        static let readableWidth: CGFloat = 620
    }

    enum Motion {
        /// Default for state changes the user triggers directly.
        static let snappy: Animation = .snappy(duration: 0.28, extraBounce: 0.04)
        /// Content appearing or reflowing.
        static let smooth: Animation = .smooth(duration: 0.32)
        /// Selection and other small, immediate feedback.
        static let quick: Animation = .snappy(duration: 0.18)
    }
}

extension View {

    /// Caps the content at one readable column and centres it in the window.
    ///
    /// A tool sheet laid out for a phone fills the screen because on a phone
    /// there is nothing else to fill; the same stack on an iPad is a row of
    /// controls stretched over two feet of glass with the window's other two
    /// thirds empty. On a phone the cap is never reached, so the layout there is
    /// untouched — which is why this is a plain width limit and not a size-class
    /// branch.
    ///
    /// Apply it to the content, *before* the background, so the background still
    /// covers the whole window.
    func readableColumn(_ maxWidth: CGFloat = DS.Layout.readableWidth) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }

    /// Opaque content surface: cards, tiles and rows.
    func contentCard(radius: CGFloat = DS.Radius.tile,
                     fill: Color = ColorPalette.surface) -> some View {
        self
            .background(fill, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(ColorPalette.separator.opacity(0.7), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    /// Floating chrome above content: action bars, overlay controls, badges.
    func floatingGlass(radius: CGFloat = DS.Radius.control,
                       tint: Color? = nil,
                       interactive: Bool = false) -> some View {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return self.glassEffect(glass, in: .rect(cornerRadius: radius, style: .continuous))
    }

    /// Capsule-shaped floating chrome, for pills and single controls.
    func floatingGlassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return self.glassEffect(glass, in: .capsule)
    }
}
