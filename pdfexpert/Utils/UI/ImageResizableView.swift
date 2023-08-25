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
    
    @State var bottomLeft: CGPoint
    @State var bottomRight: CGPoint
    @State var topLeft: CGPoint
    @State var topRight: CGPoint
    
    @State var tapImageOffset: CGPoint? = nil
    
    var computedCenter: CGPoint {
        CGPoint(x: self.bottomLeft.x + (self.bottomRight.x - self.bottomLeft.x) / 2,
                y: self.topLeft.y + (self.bottomLeft.y - self.topLeft.y) / 2)
    }
    
    var computedSize: CGSize {
        CGSize(width: self.bottomRight.x - self.bottomLeft.x,
               height: self.bottomLeft.y - self.topLeft.y)
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
        self.bottomLeft = CGPoint(x: imageRect.wrappedValue.origin.x,
                                  y: imageRect.wrappedValue.origin.y + imageRect.wrappedValue.size.height)
        self.bottomRight = CGPoint(x: imageRect.wrappedValue.origin.x + imageRect.wrappedValue.size.width,
                                   y: imageRect.wrappedValue.origin.y + imageRect.wrappedValue.size.height)
        self.topLeft = CGPoint(x: imageRect.wrappedValue.origin.x,
                               y: imageRect.wrappedValue.origin.y)
        self.topRight = CGPoint(x: imageRect.wrappedValue.origin.x + imageRect.wrappedValue.size.width,
                                y: imageRect.wrappedValue.origin.y)
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
        self.bottomLeft = CGPoint(x: self.bottomLeft.x + currentEventTranslation.x,
                                  y: self.bottomLeft.y + currentEventTranslation.y)
        self.bottomRight = CGPoint(x: self.bottomRight.x + currentEventTranslation.x,
                                   y: self.bottomRight.y + currentEventTranslation.y)
        self.topLeft = CGPoint(x: self.topLeft.x + currentEventTranslation.x,
                               y: self.topLeft.y + currentEventTranslation.y)
        self.topRight = CGPoint(x: self.topRight.x + currentEventTranslation.x,
                                y: self.topRight.y + currentEventTranslation.y)
        self.updateRect()
    }
    
    private func OnDrag(handlePosition: HandlePosition,
                        dragGestureValue: DragGesture.Value,
                        parentViewSize: CGSize) {
        
        let location = dragGestureValue.location

        switch handlePosition {
        case .bottomLeft:
            self.bottomLeft = CGPoint(x: location.x,
                                      y: location.y)
            .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
            self.bottomLeft = CGPoint(
                x: min(self.bottomLeft.x, self.bottomRight.x - self.handleSize),
                y: max(self.bottomLeft.y, self.topLeft.y + self.handleSize)
            )
            self.bottomRight = CGPoint(x: self.bottomRight.x, y: self.bottomLeft.y)
            self.topLeft = CGPoint(x: self.bottomLeft.x, y: self.topLeft.y)
        case .bottomRight:
            self.bottomRight = CGPoint(x: location.x,
                                       y: location.y)
            .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
            self.bottomRight = CGPoint(
                x: max(self.bottomRight.x, self.bottomLeft.x + self.handleSize),
                y: max(self.bottomRight.y, self.topRight.y + self.handleSize)
            )
            self.bottomLeft = CGPoint(x: self.bottomLeft.x, y: self.bottomRight.y)
            self.topRight = CGPoint(x: self.bottomRight.x, y: self.topRight.y)
        case .topLeft:
            self.topLeft = CGPoint(x: location.x,
                                   y: location.y)
            .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
            self.topLeft = CGPoint(
                x: min(self.topLeft.x, self.topRight.x - self.handleSize),
                y: min(self.topLeft.y, self.bottomLeft.y - self.handleSize)
            )
            self.bottomLeft = CGPoint(x: self.topLeft.x, y: self.bottomLeft.y)
            self.topRight = CGPoint(x: self.topRight.x, y: self.topLeft.y)
        case .topRight:
            self.topRight = CGPoint(x: location.x,
                                    y: location.y)
            .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
            self.topRight = CGPoint(
                x: max(self.topRight.x, self.topLeft.x + self.handleSize),
                y: min(self.topRight.y, self.bottomRight.y - self.handleSize)
            )
            self.bottomRight = CGPoint(x: self.topRight.x, y: self.bottomRight.y)
            self.topLeft = CGPoint(x: self.topLeft.x, y: self.topRight.y)
        }
        self.updateRect()
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

    private func updateRect() {
        self.imageRect = CGRect(x: self.topLeft.x,
                                y: self.topLeft.y,
                                width: self.bottomRight.x - self.topLeft.x,
                                height: self.bottomRight.y - self.topLeft.y)
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
