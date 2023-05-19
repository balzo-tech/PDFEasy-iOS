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
    let onSaved: () -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        self.canvasView.drawingPolicy = .anyInput
        
        // Needed to prevent dark colors (e.g: black) to be converted to bright colors
        // (and vice versa) in case of dark mode.
        self.canvasView.overrideUserInterfaceStyle = .light
        
        self.canvasView.tool = PKInkingTool(.pen, color: UIColor(self.inkColor), width: 15)
        self.canvasView.backgroundColor = UIColor(self.backgroundColor)
        
        return self.canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {}
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
