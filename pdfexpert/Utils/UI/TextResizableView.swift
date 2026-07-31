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
    
    enum FocusField: Hashable {
        case field
    }
    
    @Binding var data: TextResizableViewData
    let fontName: String
    let fontColor: UIColor
    let color: Color
    let borderWidth: CGFloat
    let minSize: CGSize
    let handleSize: CGFloat
    let handleTapSize: CGFloat
    let deleteCallback: TextResizableViewDeleteCallback
    let suggestedWords: [String]
    
    /// Name of the fixed coordinate space the drags are measured in.
    private static let canvasSpace = "textResizableCanvas"

    @State private var tapOffset: CGPoint? = nil
    @FocusState private var focusedField: FocusField?
    @State private var filteredSuggestedWords: [String] = []
    
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
        UIFont.font(named: self.fontName,
                    fitting: self.data.text,
                    into: self.computedSize,
                    with: [:],
                    options: [])
    }
    
    init(data: Binding<TextResizableViewData>,
         fontName: String,
         fontColor: UIColor,
         color: Color,
         borderWidth: CGFloat,
         minSize: CGSize,
         handleSize: CGFloat,
         handleTapSize: CGFloat,
         suggestedWords: [String],
         deleteCallback: @escaping TextResizableViewDeleteCallback) {
        self._data = data
        self.fontName = fontName
        self.fontColor = fontColor
        self.color = color
        self.borderWidth = borderWidth
        self.minSize = minSize
        self.handleSize = handleSize
        self.handleTapSize = handleTapSize
        self.suggestedWords = suggestedWords
        self.deleteCallback = deleteCallback
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.clear)
                .contentShape(Rectangle())
                .allowsHitTesting(self.focusedField == .field)
                .onTapGesture {
                    self.focusedField = .none
                }
            GeometryReader { parentGeometryReader in
                // A coordinate space that does not move. The drag gestures below
                // are attached to views that are being repositioned by the very
                // drag being measured, and `DragGesture` reports its location in
                // the coordinate space of the view it is attached to — so each
                // update moved the frame of reference, and the box stuttered
                // instead of following the finger. Measured against the container
                // instead, the numbers stay in one system.
                ZStack {
                    GeometryReader { _ in
                        // No placeholder, and no empty one either: the first
                        // argument of `TextField("", …)` is a localizable key, so
                        // it lands in the string catalog as a blank entry that no
                        // translator can act on — and the localization lint fails
                        // on it the next time a build extracts strings.
                        TextField(text: self.$data.text, prompt: nil) { EmptyView() }
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .font(Font(self.font))
                            .foregroundColor(Color(self.fontColor))
                            .focused(self.$focusedField, equals: .field)
                            .onAppear {
                                self.tapOffset = nil
                                // Dispatch on main thread is currently necessary
                                // to avoid memory leak on the view model of the parent view.
                                DispatchQueue.main.async {
                                    self.focusedField = .field
                                }
                            }
                            .contentShape(Rectangle())
                            .frame(width: self.computedSize.width, height: self.computedSize.height)
                            .background(Rectangle().stroke(self.color, lineWidth: self.borderWidth))
                            .position(self.computedCenter)
                            // `highPriorityGesture`, and a minimum distance: the
                            // box is a `TextField`, and a text field's own gesture
                            // recognisers — cursor placement, selection — win the
                            // race against an ordinary `.gesture`. SwiftUI then
                            // delivered the drag only once the touch ended, which
                            // is exactly the report: the frame jumped to its new
                            // position when the finger lifted instead of following
                            // it. Winning the race makes the drag continuous; the
                            // eight points leave a tap to the field, so tapping
                            // the text still puts the cursor in it.
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 8,
                                            coordinateSpace: .named(Self.canvasSpace))
                                    .onChanged { gesture in
                                        self.OnDrag(dragGestureValue: gesture,
                                                    parentViewSize: parentGeometryReader.size)
                                    }
                                    .onEnded { _ in self.tapOffset = nil }
                            )
                            // The bar over the keyboard. It used to hold the
                            // suggested words and nothing else, so with no
                            // suggestions to show — which is most of the time, since
                            // they only come from the personal-details form — it was
                            // an empty white strip.
                            //
                            // "Done" is what makes the tool usable at all: the page
                            // deliberately does not move when the keyboard opens (it
                            // would drag the box's frame of reference with it), so a
                            // box near the bottom sits under the keyboard with no way
                            // to reach it. Putting the keyboard away gives the whole
                            // page back, and tapping the box brings it up again.
                            .toolbar {
                                ToolbarItem(placement: .keyboard) {
                                    // Opaque, and not a material: the bar sits over
                                    // the page being edited, and over a dark page it
                                    // had nothing of its own to be seen against —
                                    // the report was that on a black PDF the bar
                                    // vanished, Done and all.
                                    HStack(spacing: DS.Spacing.sm) {
                                        if !self.filteredSuggestedWords.isEmpty {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(self.filteredSuggestedWords, id: \.self) { suggestedWord in
                                                        Button(action: {
                                                            self.data.text = suggestedWord
                                                        }) {
                                                            Text(suggestedWord)
                                                                .foregroundStyle(.white)
                                                                .font(FontCategory.body2.font.bold())
                                                                .padding(.horizontal, DS.Spacing.sm)
                                                                .padding(.vertical, DS.Spacing.xxs)
                                                        }
                                                        .background(ColorPalette.accent, in: .capsule)
                                                    }
                                                }
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        Button(String(localized: "Done")) {
                                            self.focusedField = .none
                                        }
                                        .fontWeight(.semibold)
                                        .foregroundStyle(ColorPalette.accent)
                                    }
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xxs)
                                    .frame(maxWidth: .infinity)
                                    .background(ColorPalette.surfaceElevated)
                                }
                            }
                            .onChange(of: self.data.text) { _ in
                                self.updateFilteredSuggestedWords()
                            }
                    }
                    self.getResizeHandle(parentViewSize: parentGeometryReader.size)
                    self.getDeleteButton(parentViewSize: parentGeometryReader.size)
                }
                .coordinateSpace(name: Self.canvasSpace)
            }
        }
    }
    
    private func OnDrag(dragGestureValue: DragGesture.Value, parentViewSize: CGSize) {
        
        let location = dragGestureValue.location
        let center = self.computedCenter
        let size = self.computedSize
        
        if self.tapOffset == nil {
            self.tapOffset = CGPoint(x: dragGestureValue.startLocation.x - center.x,
                                          y: dragGestureValue.startLocation.y - center.y)
        }
        
        guard let tapOffset = self.tapOffset else {
            return
        }
        
        var newCenterX = location.x - tapOffset.x
        newCenterX = max(min(newCenterX, parentViewSize.width - size.width / 2), size.width / 2)
        var newCenterY = location.y - tapOffset.y
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
            x: max(bottomRight.x, self.topLeft.x + self.minSize.width),
            y: max(bottomRight.y, self.topLeft.y + self.minSize.height)
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
            DragGesture(coordinateSpace: .named(Self.canvasSpace))
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
    
    private func updateFilteredSuggestedWords() {
        self.filteredSuggestedWords = self.suggestedWords
            .filter { $0.hasPrefix(self.data.text) && !self.data.text.isEmpty && $0 != self.data.text }
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
                              fontName: "Arial",
                              fontColor: .white,
                              color: .orange,
                              borderWidth: 4,
                              minSize: CGSize(width: 5, height: 5),
                              handleSize: 25,
                              handleTapSize: 50,
                              suggestedWords: ["Merlin", "Wizard", "North-West Tower"],
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
