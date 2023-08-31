//
//  PopupView.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 31/08/23.
//

import SwiftUI

struct PopupView<PopupContent: View>: ViewModifier {

    @Binding var isPresenting: Bool
    let backgroundColor: Color
    let tapToDismiss: Bool
    var popupContent: () -> PopupContent
    
    private var screen: CGRect {
        return UIScreen.main.bounds
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack{
                    if self.isPresenting {
                        self.backgroundView
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                self.popupContent()
                                    .transition(.move(edge: .bottom))
                                Spacer()
                            }
                            Spacer()
                        }
                        .transition(.move(edge: .bottom))
                    }
                }.frame(width: self.screen.width,
                        height: self.screen.height)
                .edgesIgnoringSafeArea(.all)
                .animation(.easeOut, value: self.isPresenting)
            )
    }
    
    @ViewBuilder var backgroundView: some View {
        let color = self.backgroundColor
        if self.tapToDismiss {
            color.onTapGesture {
                self.isPresenting = false
            }
        } else {
            color
        }
    }
}

extension View {
    func popup<PopupContent: View> (
        isPresenting: Binding<Bool>,
        backgroundColor: Color = Color.black.opacity(0.3),
        tapToDismiss: Bool = true,
        @ViewBuilder popupContent: @escaping () -> PopupContent
    ) -> some View {
        self.modifier(PopupView(isPresenting: isPresenting,
                                backgroundColor: backgroundColor,
                                tapToDismiss: tapToDismiss,
                                popupContent: popupContent))
    }
}

struct PopupView_Previews: PreviewProvider {
    
    static var previews: some View {
        Color.white
        .popup(
            isPresenting: .constant(true)
        ) {
            Color.red.frame(width: 200, height: 300)
        }
    }
}
