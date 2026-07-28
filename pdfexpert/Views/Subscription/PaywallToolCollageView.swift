//
//  PaywallToolCollageView.swift
//  PdfExpert
//
//  The paywall's headpiece: the app's tools scattered across the top of the
//  screen, drifting slowly, each on its own beat so the group never lines up
//  into a pulse.
//
//  Deliberately not a grid. A grid reads as a feature list — something to audit,
//  three of which the reader will find they do not need. Scattered and in motion
//  it reads as "there is a lot here", which is the only claim this part of the
//  screen has to make; the two cards below do the arguing.
//
//  The Office tiles borrow the colors those formats are recognised by and pair
//  them with our own symbols. Shipping Microsoft's actual marks on a screen that
//  asks for money is a trademark problem, and the color alone does the work.
//

import SwiftUI

struct PaywallToolCollageView: View {

    private struct FloatingTool: Identifiable {
        let id: Int
        let systemImage: String
        let tint: Color
        /// Where the tile sits in the collage, 0…1 on both axes.
        let position: UnitPoint
        let side: CGFloat
        /// How far it drifts from its resting place, in points.
        let drift: CGFloat
        /// How far it tilts while drifting, in degrees.
        let tilt: Double
        let duration: Double
        let delay: Double
        /// Tiles set back from the front are dimmed and softened.
        let depth: CGFloat
    }

    // Hand-placed rather than generated: a random scatter clumps, and a scatter
    // that clumps looks like a bug. Big tiles hold the two diagonals, small ones
    // fill the gaps and sit further back.
    private static let tools: [FloatingTool] = [
        FloatingTool(id: 0, systemImage: "doc.richtext", tint: ColorPalette.formatWord,
                     position: UnitPoint(x: 0.17, y: 0.22), side: 62,
                     drift: 9, tilt: 3.5, duration: 3.6, delay: 0.0, depth: 0),
        FloatingTool(id: 1, systemImage: "tablecells", tint: ColorPalette.formatExcel,
                     position: UnitPoint(x: 0.50, y: 0.09), side: 46,
                     drift: 12, tilt: -4, duration: 4.2, delay: 0.5, depth: 0.35),
        FloatingTool(id: 2, systemImage: "rectangle.on.rectangle", tint: ColorPalette.formatPowerPoint,
                     position: UnitPoint(x: 0.82, y: 0.20), side: 56,
                     drift: 10, tilt: 4, duration: 3.2, delay: 1.1, depth: 0.15),
        FloatingTool(id: 3, systemImage: "signature", tint: ColorPalette.categoryEdit,
                     position: UnitPoint(x: 0.35, y: 0.45), side: 54,
                     drift: 8, tilt: -3, duration: 3.9, delay: 0.2, depth: 0.1),
        FloatingTool(id: 4, systemImage: "doc.viewfinder", tint: ColorPalette.categoryCreate,
                     position: UnitPoint(x: 0.69, y: 0.50), side: 66,
                     drift: 11, tilt: 3, duration: 3.4, delay: 0.8, depth: 0),
        FloatingTool(id: 5, systemImage: "lock.shield", tint: ColorPalette.categoryProtect,
                     position: UnitPoint(x: 0.09, y: 0.57), side: 44,
                     drift: 13, tilt: 5, duration: 4.5, delay: 1.4, depth: 0.4),
        FloatingTool(id: 6, systemImage: "arrow.trianglehead.merge", tint: ColorPalette.categoryOrganize,
                     position: UnitPoint(x: 0.93, y: 0.68), side: 42,
                     drift: 10, tilt: -5, duration: 4.0, delay: 0.3, depth: 0.45),
        FloatingTool(id: 7, systemImage: "sparkles", tint: ColorPalette.categoryAi,
                     position: UnitPoint(x: 0.47, y: 0.75), side: 58,
                     drift: 9, tilt: 4, duration: 3.7, delay: 1.7, depth: 0.05),
        FloatingTool(id: 8, systemImage: "text.viewfinder", tint: ColorPalette.categoryEdit,
                     position: UnitPoint(x: 0.20, y: 0.86), side: 46,
                     drift: 12, tilt: -3.5, duration: 4.3, delay: 0.9, depth: 0.3),
        FloatingTool(id: 9, systemImage: "photo.on.rectangle.angled", tint: ColorPalette.categoryCreate,
                     position: UnitPoint(x: 0.74, y: 0.89), side: 50,
                     drift: 8, tilt: 3, duration: 3.1, delay: 1.9, depth: 0.2),
        FloatingTool(id: 10, systemImage: "book", tint: ColorPalette.categoryRead,
                     position: UnitPoint(x: 0.95, y: 0.40), side: 38,
                     drift: 14, tilt: -4.5, duration: 4.8, delay: 0.6, depth: 0.5),
        FloatingTool(id: 11, systemImage: "scissors", tint: ColorPalette.categoryOrganize,
                     position: UnitPoint(x: 0.06, y: 0.90), side: 36,
                     drift: 11, tilt: 4, duration: 4.6, delay: 1.3, depth: 0.55),
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDrifting: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                self.glow(in: geometry.size)
                ForEach(Self.tools) { tool in
                    self.tile(for: tool)
                        .position(x: geometry.size.width * tool.position.x,
                                  y: geometry.size.height * tool.position.y)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
        // Without this the collage ends on a hard rectangle, and a hard
        // rectangle in the middle of a screen reads as a placeholder image
        // someone forgot to replace. Faded at the edges it reads as depth.
        .mask(self.edgeFade)
        .onAppear {
            guard !self.reduceMotion else { return }
            self.isDrifting = true
        }
        .accessibilityHidden(true)
    }

    private var edgeFade: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0),
                               .init(color: .black, location: 0.14),
                               .init(color: .black, location: 0.84),
                               .init(color: .clear, location: 1)],
                       startPoint: .top, endPoint: .bottom)
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: .black, location: 0.10),
                                   .init(color: .black, location: 0.90),
                                   .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
    }

    /// A soft wash of brand color behind the tiles, so they read as floating in
    /// front of something rather than pasted onto the background.
    private func glow(in size: CGSize) -> some View {
        RadialGradient(colors: [ColorPalette.accent.opacity(0.28),
                                ColorPalette.accentSecondary.opacity(0.10),
                                .clear],
                       center: .center,
                       startRadius: 0,
                       endRadius: max(size.width, size.height) * 0.62)
        .blur(radius: 24)
    }

    private func tile(for tool: FloatingTool) -> some View {
        let radius: CGFloat = tool.side * 0.29
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let symbolSize: CGFloat = tool.side * 0.44
        let shadowOpacity: Double = 0.25 * (1 - Double(tool.depth))

        let face = Image(systemName: tool.systemImage)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(tool.tint)
            .frame(width: tool.side, height: tool.side)
            .background(tool.tint.opacity(0.16), in: shape)
            .overlay { shape.strokeBorder(tool.tint.opacity(0.35), lineWidth: 1) }
            .shadow(color: tool.tint.opacity(shadowOpacity), radius: 12, y: 6)

        return self.settingBack(face, by: tool.depth)
            .rotationEffect(.degrees(self.isDrifting ? tool.tilt : -tool.tilt))
            .offset(y: self.isDrifting ? -tool.drift : tool.drift)
            .animation(self.driftAnimation(for: tool), value: self.isDrifting)
    }

    /// Pushes a tile back into the collage: dimmer, softer and slightly smaller,
    /// so the twelve of them read as a depth of field rather than a wall.
    private func settingBack<Content: View>(_ content: Content, by depth: CGFloat) -> some View {
        content
            .opacity(1 - Double(depth) * 0.55)
            .blur(radius: depth * 1.6)
            .scaleEffect(1 - depth * 0.08)
    }

    private func driftAnimation(for tool: FloatingTool) -> Animation? {
        guard !self.reduceMotion else { return nil }
        return .easeInOut(duration: tool.duration)
            .repeatForever(autoreverses: true)
            .delay(tool.delay)
    }
}

#Preview("Tool collage") {
    PaywallToolCollageView()
        .frame(height: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorPalette.background)
}
