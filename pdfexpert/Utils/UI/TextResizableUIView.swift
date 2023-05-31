//
//  TextResizableUIView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 29/05/23.
//

import Foundation
import UIKit
import PDFKit

class TextResizableUIView: UIView {
    
    private let annotation: PDFAnnotation
    
    private let textField: UITextField = {
        let textField = UITextField()
        textField.textColor = .black
        textField.font = UIFont.systemFont(ofSize: 20)
        return textField
    }()
    
    private var initialCenter = CGPoint()
    
    init(annotation: PDFAnnotation) {
        self.annotation = annotation
        super.init(frame: .zero)
        self.addSubview(self.textField)
        self.textField.frame = annotation.bounds
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
        self.textField.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture)))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func tap() {
        debugPrint(for: self, message: "Tap!")
    }
    
    @objc func panGesture(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard let draggedView = gestureRecognizer.view, self.textField == draggedView else { return }
        // Get the changes in the X and Y directions relative to
        // the superview's coordinate space.
        let translation = gestureRecognizer.translation(in: draggedView.superview)
        if gestureRecognizer.state == .began {
            // Save the view's original position.
            self.initialCenter = draggedView.center
        }
        // Update the position for the .began, .changed, and .ended states
        if gestureRecognizer.state != .cancelled {
            // Add the X and Y translation to the view's original position.
            let newCenter = CGPoint(x: self.initialCenter.x + translation.x, y: self.initialCenter.y + translation.y)
            draggedView.center = newCenter
        }
        else {
            // On cancellation, return the piece to its original location.
            draggedView.center = self.initialCenter
        }
    }
}
