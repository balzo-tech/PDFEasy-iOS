//
//  CameraFrameGuide.swift
//  PdfExpert
//
//  The outline drawn over the camera preview to say where the subject goes.
//
//  Deliberately a plain value rather than a passport specification: the camera
//  is shared by half the app, and it should not have to know what a passport is
//  to draw a rectangle with two lines in it. Whoever presents the camera works
//  out the proportions and hands them over.
//
//  ⚠️ It is **guidance, not a promise**. The photograph is captured at the
//  sensor's full frame and the crop is worked out afterwards from where the face
//  actually is, so lining the head up here is a way of getting a photo that will
//  crop well — not a preview of the crop. Saying otherwise on screen would be a
//  lie the first time someone's head landed a few millimetres off.
//

import SwiftUI

struct CameraFrameGuide: Equatable {

    /// Width over height of the frame to draw.
    let aspectRatio: CGFloat
    /// Where the top of the head goes, as a fraction of the frame's height from
    /// its top edge.
    let crownFractionFromTop: CGFloat
    /// Where the chin goes, same units.
    let chinFractionFromTop: CGFloat
    /// One line under the frame, telling the user what to do with it.
    let caption: String
}

extension CameraFrameGuide {

    /// The guide for a country's identity photo.
    init(spec: PassportPhotoSpec) {
        self.init(aspectRatio: spec.aspectRatio,
                  crownFractionFromTop: spec.crownFractionFromTop,
                  chinFractionFromTop: spec.chinFractionFromTop,
                  caption: String(localized: "Fit the top of your head and your chin between the two lines."))
    }
}

/// The frame, the head outline and the two lines, over a dimmed background.
struct CameraFrameGuideView: View {

    let guide: CameraFrameGuide

    var body: some View {
        GeometryReader { proxy in
            // The frame is as tall as the preview allows, and as wide as its own
            // proportions then make it — the same way round as the editor, so
            // what the user lines up here is what the editor will show them.
            let height = min(proxy.size.height * 0.82, proxy.size.width * 1.5 / self.guide.aspectRatio)
            let width = height * self.guide.aspectRatio
            let frame = CGRect(x: (proxy.size.width - width) / 2,
                               y: (proxy.size.height - height) / 2,
                               width: width,
                               height: height)
            ZStack {
                self.dimming(around: frame, in: proxy.size)
                self.outline(in: frame)
                self.head(in: frame)
                self.line(in: frame, at: self.guide.crownFractionFromTop)
                self.line(in: frame, at: self.guide.chinFractionFromTop)
                self.caption(under: frame, in: proxy.size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Everything outside the frame, darkened. An even-odd fill rather than four
    /// rectangles: the corners are where a four-rectangle version shows its
    /// seams, and they are the part the eye follows.
    private func dimming(around frame: CGRect, in size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRoundedRect(in: frame, cornerSize: CGSize(width: 12, height: 12))
        }
        .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
    }

    private func outline(in frame: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }

    /// A head-shaped oval between the two lines: the width is what stops people
    /// filling the whole frame with their face, which two horizontal lines on
    /// their own do not.
    private func head(in frame: CGRect) -> some View {
        let top = frame.minY + self.guide.crownFractionFromTop * frame.height
        let bottom = frame.minY + self.guide.chinFractionFromTop * frame.height
        let height = max(bottom - top, 1)
        // Roughly three quarters as wide as it is tall, which is the proportion
        // of a human head seen from the front.
        let width = height * 0.74
        return Ellipse()
            .strokeBorder(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            .frame(width: width, height: height)
            .position(x: frame.midX, y: (top + bottom) / 2)
    }

    private func line(in frame: CGRect, at fraction: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.9))
            .frame(width: frame.width, height: 1)
            .position(x: frame.midX, y: frame.minY + fraction * frame.height)
    }

    private func caption(under frame: CGRect, in size: CGSize) -> some View {
        Text(self.guide.caption)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.45), in: .capsule)
            .frame(maxWidth: size.width - 32)
            .position(x: size.width / 2, y: min(frame.maxY + 26, size.height - 20))
    }
}
