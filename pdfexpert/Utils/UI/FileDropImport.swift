//
//  FileDropImport.swift
//  PdfExpert
//
//  Dragging a file onto the window is how a document gets into an app on a Mac,
//  and the app already knows what to do with one — it is the same path a file
//  arriving from "Copy to PDF Pro" takes. This only opens the door and says so
//  while a file is over it.
//
//  It works on an iPad too, where a file can be dragged in from Files or from a
//  second app alongside.
//

import SwiftUI

private struct FileDropImport: ViewModifier {

    @Binding var isTargeted: Bool
    let onDrop: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self) { urls, _ in
                // Only the first. What follows a dropped file — staging it,
                // converting it, opening the editor on it — carries one document
                // at a time, and starting it three times over would leave two of
                // them with nowhere to land.
                guard let url = urls.first else { return false }
                self.onDrop(url)
                return true
            } isTargeted: { targeted in
                withAnimation(DS.Motion.quick) { self.isTargeted = targeted }
            }
            .overlay {
                if self.isTargeted {
                    self.dropIndicator
                }
            }
    }

    private var dropIndicator: some View {
        ZStack {
            ColorPalette.background.opacity(0.82)

            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(ColorPalette.accent)
                Text("Drop the file to open it")
                    .font(FontPalette.fontMedium(withSize: 18))
                    .foregroundStyle(ColorPalette.textPrimary)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .strokeBorder(ColorPalette.accent,
                              style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(DS.Spacing.md)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

extension View {

    /// Accepts a document dragged onto the view and hands it over as a file URL.
    func droppedFileImport(isTargeted: Binding<Bool>, onDrop: @escaping (URL) -> Void) -> some View {
        self.modifier(FileDropImport(isTargeted: isTargeted, onDrop: onDrop))
    }
}
