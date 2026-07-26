//
//  PencilKitView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 19/05/23.
//

import SwiftUI
import PencilKit
import UIKit

struct PencilKitView: UIViewRepresentable {
    
    @Binding var canvasView: PKCanvasView
    
    let backgroundColor: Color
    let inkColor: Color
    /// iPad only. Shows the system palette and switches the canvas to the
    /// drawing policy that ignores fingers while a Pencil is paired, so a hand
    /// resting on the glass does not sign for you. With no Pencil around the
    /// policy still accepts touches, so a finger-only iPad loses nothing.
    var showsToolPicker: Bool = false
    let onSaved: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        self.canvasView.drawingPolicy = self.showsToolPicker ? .default : .anyInput

        // Needed to prevent dark colors (e.g: black) to be converted to bright colors
        // (and vice versa) in case of dark mode.
        self.canvasView.overrideUserInterfaceStyle = .light

        self.canvasView.tool = PKInkingTool(.pen, color: UIColor(self.inkColor), width: 15)
        self.canvasView.backgroundColor = UIColor(self.backgroundColor)

        return self.canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        context.coordinator.updateToolPicker(visible: self.showsToolPicker, for: canvasView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Owns the picker: `PKToolPicker` has to outlive a single `updateUIView`
    /// pass, and it attaches to a responder rather than to a view hierarchy.
    final class Coordinator {

        private let toolPicker = PKToolPicker()

        func updateToolPicker(visible: Bool, for canvasView: PKCanvasView) {
            // It can only attach once the canvas is in a window, and SwiftUI
            // runs the first update pass before that has happened.
            guard visible, canvasView.window != nil else {
                self.toolPicker.setVisible(false, forFirstResponder: canvasView)
                return
            }
            self.toolPicker.addObserver(canvasView)
            self.toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }
    }
}

struct PencilKitView_Previews: PreviewProvider {
    
    static let canvasView = PKCanvasView()
    
    static var previews: some View {
        PencilKitView(canvasView: .constant(canvasView),
                      backgroundColor: .white,
                      inkColor: .black,
                      onSaved: { print("PencilKitView - On Saved") })
    }
}
