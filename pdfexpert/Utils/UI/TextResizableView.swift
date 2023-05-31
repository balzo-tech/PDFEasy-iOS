//
//  TextResizableView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 26/05/23.
//

import SwiftUI
import UIKit

typealias TextResizableViewDeleteCallback = (() -> ())

struct TextResizableViewData {
    var text: String
    var rect: CGRect
}

struct TextResizableView: View {
    
    fileprivate enum TextResizableViewState {
        case unselected
        case selected
        case editingText
    }
    
    enum FocusField: Hashable {
        case field
      }
    
    @Binding var data: TextResizableViewData
    let fontFamilyName: String?
    let fontColor: UIColor
    let color: Color
    let borderWidth: CGFloat
    let handleSize: CGFloat
    let handleTapSize: CGFloat
    let deleteCallback: TextResizableViewDeleteCallback
    
//    @State private var text: String { didSet { self.updateRect() } }
//    @Binding private var bottomRight: CGPoint
//    @Binding private var topLeft: CGPoint
    @State private var textSize: CGFloat = K.Misc.DefaultAnnotationTextFontSize
    
    @State private var state: TextResizableViewState = .unselected
    
    @State private var tapOffset: CGPoint? = nil
    @FocusState private var focusedField: FocusField?
    
    private var topLeft: CGPoint {
        self.data.rect.origin
    }
    
    private var bottomRight: CGPoint {
        CGPoint(x: self.data.rect.origin.x + self.data.rect.size.width,
                y: self.data.rect.origin.y + self.data.rect.size.height)
    }
    
    private var computedCenter: CGPoint {
        CGPoint(x: self.topLeft.x + (self.bottomRight.x - self.topLeft.x) / 2,
                y: self.topLeft.y + (self.bottomRight.y - self.topLeft.y) / 2)
    }
    
    private var computedSize: CGSize {
        CGSize(width: self.bottomRight.x - self.topLeft.x,
               height: self.bottomRight.y - self.topLeft.y)
    }
    
    private var font: UIFont {
        let defaultFont = UIFont.systemFont(ofSize: self.textSize)
        if let fontFamilyName = self.fontFamilyName {
            return UIFont(name: fontFamilyName, size: self.textSize) ?? defaultFont
        } else {
            return defaultFont
        }
    }
    
    init(data: Binding<TextResizableViewData>,
         fontFamilyName: String?,
         fontColor: UIColor,
         color: Color,
         borderWidth: CGFloat,
         handleSize: CGFloat,
         handleTapSize: CGFloat,
         deleteCallback: @escaping TextResizableViewDeleteCallback) {
        self._data = data
        self.fontFamilyName = fontFamilyName
        self.fontColor = fontColor
        self.color = color
        self.borderWidth = borderWidth
        self.handleSize = handleSize
        self.handleTapSize = handleTapSize
        self.deleteCallback = deleteCallback
    }
    
    var body: some View {
        GeometryReader { parentGeometryReader in
            ZStack {
                GeometryReader { _ in
                    TextField("", text: self.$data.text)
                        .multilineTextAlignment(.center)
                        .font(Font(self.font))
                        .foregroundColor(Color(self.fontColor))
                        .focused(self.$focusedField, equals: .field)
//                        .onAppear {
//                            self.focusedField = .field
//                        }
                        .onTapGesture {
                            self.state = .selected
                        }
                        .frame(width: self.computedSize.width, height: self.computedSize.height)
                        .background(self.backgroundView)
                        .position(self.computedCenter)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    self.OnDrag(dragGestureValue: gesture,
                                                parentViewSize: parentGeometryReader.size)
                                }
                                .onEnded { _ in self.tapOffset = nil }
                        )
                }
                if self.state == .selected {
                    self.getResizeHandle(parentViewSize: parentGeometryReader.size)
                    self.getDeleteButton(parentViewSize: parentGeometryReader.size)
                }
            }
        }
    }
    
    @ViewBuilder private var backgroundView: some View {
        if self.state == .selected {
            Rectangle().stroke(self.color, lineWidth: self.borderWidth)
        } else {
            Color.clear
        }
//        Color.red
    }
    
    private func OnDrag(dragGestureValue: DragGesture.Value, parentViewSize: CGSize) {
        
        let location = dragGestureValue.location
        let center = self.computedCenter
        let size = self.computedSize
        
        if self.tapOffset == nil {
            self.tapOffset = CGPoint(x: dragGestureValue.startLocation.x - center.x,
                                          y: dragGestureValue.startLocation.y - center.y)
        }
        
        guard let tapImageOffset = self.tapOffset else {
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
        self.updateRect(topLeft: topLeft, bottomRight: bottomRight, text: self.data.text)
    }
    
    private func onResizeDrag(dragGestureValue: DragGesture.Value, parentViewSize: CGSize) {
        
        let location = dragGestureValue.location
        
        var bottomRight = CGPoint(x: location.x,y: location.y)
            .getBoundedPoint(containerSize: parentViewSize, margin: self.handleSize / 2)
        bottomRight = CGPoint(
            x: max(bottomRight.x, self.topLeft.x + self.handleSize),
            y: max(bottomRight.y, self.topLeft.y + self.handleSize)
        )
        
        self.updateRect(topLeft: self.topLeft, bottomRight: bottomRight, text: self.data.text)
    }

    private func getResizeHandle(parentViewSize: CGSize) -> some View {
        ZStack {
            Circle()
                .frame(width: self.handleSize, height: self.handleSize)
                .foregroundColor(.white)
            Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                .resizable()
                .frame(width: self.handleSize, height: self.handleSize)
                .foregroundColor(self.color)
        }
        .frame(width: self.handleTapSize, height: self.handleTapSize)
        .contentShape(Circle())
        .position(CGPoint(x: self.computedCenter.x + self.computedSize.width / 2,
                          y: self.computedCenter.y + self.computedSize.height / 2))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    self.onResizeDrag(dragGestureValue: gesture, parentViewSize: parentViewSize)
                }
        )
    }
    
    private func getDeleteButton(parentViewSize: CGSize) -> some View {
        Button(action: { self.deleteCallback() }) {
            ZStack {
                Circle()
                    .frame(width: self.handleSize, height: self.handleSize)
                    .foregroundColor(.white)
                Image(systemName: "trash.circle.fill")
                    .resizable()
                    .frame(width: self.handleSize, height: self.handleSize)
                    .foregroundColor(self.color)
            }
        }
        .frame(width: self.handleTapSize, height: self.handleTapSize)
        .contentShape(Circle())
        .position(CGPoint(x: self.computedCenter.x - self.computedSize.width / 2,
                          y: self.computedCenter.y - self.computedSize.height / 2))
    }

    private func updateRect(topLeft: CGPoint, bottomRight: CGPoint, text: String) {
        let rect = CGRect(x: topLeft.x,
                          y: topLeft.y,
                          width: bottomRight.x - topLeft.x,
                          height: bottomRight.y - topLeft.y)
        self.data = TextResizableViewData(text: self.data.text, rect: rect)
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

struct TextResizableView_Previews: PreviewProvider {
    
    static let size: CGSize = CGSize(width: 100, height: 50)
    static let text: String = "Test String"
    
    static var previews: some View {
        GeometryReader { geometryReader in
            TextResizableView(data: .constant(getData(forParentSize: geometryReader.size)),
                              fontFamilyName: nil,
                              fontColor: .white,
                              color: .orange,
                              borderWidth: 4,
                              handleSize: 20,
                              handleTapSize: 50,
                              deleteCallback: { print("TextResizableView_Previews - Delete callback called!") })
            .position(x: geometryReader.size.width/2, y: geometryReader.size.height/2)
            .frame(width: geometryReader.size.width, height: geometryReader.size.height)
        }
    }
    
    private static func getData(forParentSize parentSize: CGSize) -> TextResizableViewData {
        TextResizableViewData(text: text, rect: getRect(forParentSize: parentSize))
    }
    
    private static func getRect(forParentSize parentSize: CGSize) -> CGRect {
        CGRect(x: parentSize.width * 0.5 - size.width / 2,
               y: parentSize.height * 0.5 - size.height / 2,
               width: size.width,
               height: size.height)
    }
}
