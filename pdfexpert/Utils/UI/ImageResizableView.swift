//
//  ImageResizableView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 16/05/23.
//

import SwiftUI
import UIKit

typealias ImageResizableViewDeleteCallback = (() -> ())

struct ImageResizableView: View {
    
    enum HandlePosition { case bottomLeft, bottomRight, topLeft, topRight }
    
    let uiImage: UIImage
    @Binding var imageRect: CGRect
    let borderColor: Color
    let borderWidth: CGFloat
    let handleColor: Color
    let handleSize: CGFloat
    let handleTapSize: CGFloat
    let deleteCallback: ImageResizableViewDeleteCallback
    
    @State var tapImageOffset: CGPoint? = nil
    
    private var topLeft: CGPoint {
        self.imageRect.origin
    }
    
    private var bottomRight: CGPoint {
        CGPoint(x: self.imageRect.origin.x + self.imageRect.size.width,
                y: self.imageRect.origin.y + self.imageRect.size.height)
    }
    
    private var computedCenter: CGPoint {
        CGPoint(x: self.topLeft.x + (self.bottomRight.x - self.topLeft.x) / 2,
                y: self.topLeft.y + (self.bottomRight.y - self.topLeft.y) / 2)
    }
    
    private var computedSize: CGSize {
        CGSize(width: self.bottomRight.x - self.topLeft.x,
               height: self.bottomRight.y - self.topLeft.y)
    }
    
    init(uiImage: UIImage,
         imageRect: Binding<CGRect>,
         borderColor: Color,
         borderWidth: CGFloat,
         handleColor: Color,
         handleSize: CGFloat,
         handleTapSize: CGFloat,
         deleteCallback: @escaping ImageResizableViewDeleteCallback) {
        self.uiImage = uiImage
        self._imageRect = imageRect
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.handleColor = handleColor
        self.handleSize = handleSize
        self.handleTapSize = handleTapSize
        self.deleteCallback = deleteCallback
    }
    
    var body: some View {
        GeometryReader { parentGeometryReader in
            ZStack {
                GeometryReader { _ in
                    Image(uiImage: self.uiImage)
                        .resizable()
                        .background(Rectangle().stroke(self.borderColor, lineWidth: self.borderWidth))
                        .position(self.computedCenter)
                        .frame(width: self.computedSize.width, height: self.computedSize.height)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    self.OnDragImage(dragGestureValue: gesture,
                                                     parentViewSize: parentGeometryReader.size)
                                }
                                .onEnded { _ in self.tapImageOffset = nil }
                        )
                }
                self.getHandle(handlePosition: .bottomLeft,
                               parentViewSize: parentGeometryReader.size)
                self.getHandle(handlePosition: .bottomRight,
                               parentViewSize: parentGeometryReader.size)
                self.getHandle(handlePosition: .topLeft,
                               parentViewSize: parentGeometryReader.size)
                self.getHandle(handlePosition: .topRight,
                               parentViewSize: parentGeometryReader.size)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                self.deleteCallback()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func OnDragImage(dragGestureValue: DragGesture.Value, parentViewSize: CGSize) {
        
        let location = dragGestureValue.location
        let center = self.computedCenter
        let size = self.computedSize
        
        if self.tapImageOffset == nil {
            self.tapImageOffset = CGPoint(x: dragGestureValue.startLocation.x - center.x,
                                          y: dragGestureValue.startLocation.y - center.y)
        }
        
        guard let tapImageOffset = self.tapImageOffset else {
            return
        }
        
        var newCenterX = location.x - tapImageOffset.x
        newCenterX = max(min(newCenterX, parentViewSize.width - size.width / 2), size.width / 2)
        var newCenterY = location.y - tapImageOffset.y
        newCenterY = max(min(newCenterY, parentViewSize.height - size.height / 2), size.height / 2)
        
        let currentEventTranslation: CGPoint = CGPoint(x: newCenterX - center.x,
                                                       y: newCenterY - center.y)
        let bottomRight = CGPoint(x: self.bottomRight.x + currentEventTranslation.x,
                                  y: self.bottomRight.y + currentEventTranslation.y)
        let topLeft = CGPoint(x: self.topLeft.x + currentEventTranslation.x,
                              y: self.topLeft.y + currentEventTranslation.y)
        self.updateRect(topLeft: topLeft, bottomRight: bottomRight)
    }
    
    private func OnDrag(handlePosition: HandlePosition,
                        dragGestureValue: DragGesture.Value,
                        parentViewSize: CGSize) {
        
        let location = dragGestureValue.location
        
        var bottomRight: CGPoint = .zero
        var topLeft: CGPoint = .zero
        
        switch handlePosition {
        case .bottomLeft:
            var bottomLeft = CGPoint(x: location.x,
                                     y: location.y)
                .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
            bottomLeft = CGPoint(
                x: min(bottomLeft.x, self.bottomRight.x - self.handleSize),
                y: max(bottomLeft.y, self.topLeft.y + self.handleSize)
            )
            bottomRight = CGPoint(x: self.bottomRight.x, y: bottomLeft.y)
            topLeft = CGPoint(x: bottomLeft.x, y: self.topLeft.y)
        case .bottomRight:
            bottomRight = CGPoint(x: location.x,
                                  y: location.y)
            .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
            bottomRight = CGPoint(
                x: max(bottomRight.x, self.topLeft.x + self.handleSize),
                y: max(bottomRight.y, self.topLeft.y + self.handleSize)
            )
            topLeft = self.topLeft
        case .topLeft:
            topLeft = CGPoint(x: location.x,
                              y: location.y)
            .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
            topLeft = CGPoint(
                x: min(topLeft.x, self.bottomRight.x - self.handleSize),
                y: min(topLeft.y, self.bottomRight.y - self.handleSize)
            )
            bottomRight = self.bottomRight
        case .topRight:
            var topRight = CGPoint(x: location.x,
                                   y: location.y)
                .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
            topRight = CGPoint(
                x: max(topRight.x, self.topLeft.x + self.handleSize),
                y: min(topRight.y, self.bottomRight.y - self.handleSize)
            )
            bottomRight = CGPoint(x: topRight.x, y: self.bottomRight.y)
            topLeft = CGPoint(x: self.topLeft.x, y: topRight.y)
        }
        self.updateRect(topLeft: topLeft, bottomRight: bottomRight)
    }
    
    private func getHandle(handlePosition: HandlePosition,
                           parentViewSize: CGSize) -> some View {
        Group {
            Circle()
                .frame(width: self.handleSize, height: self.handleSize)
                .foregroundColor(self.handleColor)
        }
        .frame(width: self.handleTapSize, height: self.handleTapSize)
        .contentShape(Circle())
        .position(handlePosition.getPosition(forParentViewSize: self.computedSize,
                                             parentCenter: self.computedCenter))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    self.OnDrag(handlePosition: handlePosition,
                                dragGestureValue: gesture,
                                parentViewSize: parentViewSize)
                }
        )
    }
    
    private func updateRect(topLeft: CGPoint, bottomRight: CGPoint) {
        self.imageRect = CGRect(x: topLeft.x,
                                y: topLeft.y,
                                width: bottomRight.x - topLeft.x,
                                height: bottomRight.y - topLeft.y)
    }
}

fileprivate extension ImageResizableView.HandlePosition {
    func getPosition(forParentViewSize parentViewSize: CGSize, parentCenter: CGPoint) -> CGPoint {
        switch self {
        case .bottomLeft: return CGPoint(x: parentCenter.x - parentViewSize.width / 2,
                                         y: parentCenter.y + parentViewSize.height / 2)
        case .bottomRight: return CGPoint(x: parentCenter.x + parentViewSize.width / 2,
                                          y: parentCenter.y + parentViewSize.height / 2)
        case .topLeft: return CGPoint(x: parentCenter.x - parentViewSize.width / 2,
                                      y: parentCenter.y - parentViewSize.height / 2)
        case .topRight: return CGPoint(x: parentCenter.x + parentViewSize.width / 2,
                                       y: parentCenter.y - parentViewSize.height / 2)
        }
    }
}

fileprivate extension CGPoint {
    func getBoundedPoint(containerSize: CGSize, margin: CGFloat) -> CGPoint {
        return CGPoint(
            x: min(max(self.x, margin), containerSize.width - margin),
            y: min(max(self.y, margin), containerSize.height - margin)
        )
    }
}

struct ImageResizableView_Previews: PreviewProvider {
    
    static let imageSize: CGSize = CGSize(width: 200, height: 200)
    
    static var previews: some View {
        if let image = UIImage(named: "gallery") {
            GeometryReader { geometryReader in
                ImageResizableView(
                    uiImage: image,
                    imageRect: .constant(CGRect(x: geometryReader.size.width * 0.5 - imageSize.width / 2,
                                                y: geometryReader.size.height * 0.5 - imageSize.height / 2,
                                                width: imageSize.width,
                                                height: imageSize.height)),
                    borderColor: .red,
                    borderWidth: 2,
                    handleColor: .white,
                    handleSize: 10,
                    handleTapSize: 50,
                    deleteCallback: { print("Delete!") }
                )
            }
        } else {
            Spacer()
        }
    }
}
