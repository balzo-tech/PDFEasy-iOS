//
//  FullScreenClearBackground.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 10/08/23.
//

import Foundation
import SwiftUI

struct FullScreenClearBackground: UIViewControllerRepresentable {
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<Self>) -> UIViewController {
        return Controller()
    }
    
    public func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<Self>) {
    }
    
    class Controller: UIViewController {
        
        override func viewDidLoad() {
            super.viewDidLoad()
            self.view.backgroundColor = .clear
        }
        
        override func willMove(toParent parent: UIViewController?) {
            super.willMove(toParent: parent)
            parent?.view?.backgroundColor = .clear
            parent?.modalPresentationStyle = .overCurrentContext
        }
    }
}

extension View {
    @ViewBuilder public func sheetAutoHeight<Content: View>(isPresented: Binding<Bool>,
                                                            backgroundColor: Color,
                                                            topCornerRadius: CGFloat = 0,
                                                            @ViewBuilder content: @escaping () -> Content) -> some View {
        self.fullScreenCover(isPresented: isPresented) {
            Button(action: { isPresented.wrappedValue = false }) {
                self.getContentView(backgroundColor: backgroundColor,
                                    topCornerRadius: topCornerRadius,
                                    content: { content() })
            }
            .background(FullScreenClearBackground())
        }
    }
    
    @ViewBuilder public func sheetAutoHeight<Content: View, Item: Identifiable>(item: Binding<Item?>,
                                                            backgroundColor: Color,
                                                            topCornerRadius: CGFloat = 0,
                                                            @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        self.fullScreenCover(item: item) { unwrappedItem in
            Button(action: { item.wrappedValue = nil }) {
                self.getContentView(backgroundColor: backgroundColor,
                                    topCornerRadius: topCornerRadius,
                                    content: { content(unwrappedItem) })
            }
            .background(FullScreenClearBackground())
        }
    }
    
    @ViewBuilder private func getContentView<Content: View>(backgroundColor: Color,
                                                            topCornerRadius: CGFloat,
                                                            @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(spacing: 0) {
            Spacer()
            if topCornerRadius > 0 {
                backgroundColor.frame(height: topCornerRadius * 2)
                    .cornerRadius(topCornerRadius, corners: [.topLeft, .topRight])
            }
            content()
                .background(backgroundColor)
        }
    }
}
